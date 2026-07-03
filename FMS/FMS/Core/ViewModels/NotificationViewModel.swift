import Foundation
import Combine
import SwiftUI
import UIKit
import UserNotifications

enum NotificationRecipientRole {
    case driver
    case manager
    case maintenance
}

@MainActor
final class NotificationViewModel: ObservableObject {
    private let notificationService: NotificationServiceProtocol
    private var recipientId: UUID?
    private var realtimeTask: Task<Void, Never>?
    private var tripsRealtimeTask: Task<Void, Never>?
    let role: NotificationRecipientRole

    @Published var notifications: [AppNotification] = []
    @Published var unreadCount: Int = 0
    @Published var showBanner: Bool = false
    @Published var currentBanner: AppNotification?

    private var bannerQueue: [AppNotification] = []
    private var isProcessingQueue = false

    init(notificationService: NotificationServiceProtocol, recipientId: UUID?, role: NotificationRecipientRole = .driver) {
        self.notificationService = notificationService
        self.recipientId = recipientId
        self.role = role
    }

    func setRecipientId(_ id: UUID?) {
        guard self.recipientId != id else { return }
        self.recipientId = id
        if realtimeTask != nil {
            subscribeToRealtime()
        }
    }

    private func shouldIncludeNotification(_ notification: AppNotification) -> Bool {
        switch role {
        case .driver:
            return notification.recipientId == recipientId
        case .maintenance:
            if let recId = notification.recipientId {
                return recId == recipientId
            }
            let maintenanceTypes = ["work_order_request", "low_stock", "maintenance", "work_order"]
            return maintenanceTypes.contains(notification.type.lowercased())
        case .manager:
            return true
        }
    }

    private func filterNotifications(_ list: [AppNotification]) -> [AppNotification] {
        return list.filter { shouldIncludeNotification($0) }
    }

    func loadNotifications() async {
        do {
            let list = try await notificationService.fetchNotifications(for: recipientId)
            self.notifications = filterNotifications(list)
            self.unreadCount = self.notifications.filter { !$0.isRead }.count
        } catch {
            print("Failed to load notifications: \(error.localizedDescription)")
        }
    }

    func markAsRead(_ notification: AppNotification) async {
        do {
            try await notificationService.markAsRead(id: notification.id)
            if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
                notifications[index].isRead = true
                unreadCount = notifications.filter { !$0.isRead }.count
            }
        } catch {
            print("Failed to mark notification as read: \(error.localizedDescription)")
        }
    }

    func markAllAsRead() async {
        do {
            try await notificationService.markAllAsRead(for: recipientId)
            for index in 0..<notifications.count {
                notifications[index].isRead = true
            }
            unreadCount = 0
        } catch {
            print("Failed to mark all notifications as read: \(error.localizedDescription)")
        }
    }

    func subscribeToRealtime() {
        realtimeTask?.cancel()
        realtimeTask = Task {
            let stream = notificationService.subscribeToRealtime(for: recipientId)
            for await newNotification in stream {
                guard shouldIncludeNotification(newNotification) else { continue }
                self.notifications.insert(newNotification, at: 0)
                self.unreadCount += 1
                
                triggerHapticFeedback()
                enqueueBanner(newNotification)
                triggerLocalSystemNotification(title: newNotification.title, body: newNotification.message)
            }
        }

        if role == .driver, let driverId = recipientId {
            tripsRealtimeTask?.cancel()
            tripsRealtimeTask = Task {
                let stream = notificationService.subscribeToTripsRealtime(forDriverId: driverId)
                for await trip in stream {
                    // Always reload dashboard for any realtime update
                    NotificationCenter.default.post(name: NSNotification.Name("ReloadTrips"), object: nil)
                    
                    if trip.status == .scheduled || trip.status == .pending {
                        triggerHapticFeedback()
                        triggerLocalSystemNotification(
                            title: "New Trip Assigned 🚚",
                            body: "Route: \(trip.startLocation) to \(trip.endLocation)"
                        )
                    } else if trip.status == .cancelled {
                        triggerHapticFeedback()
                        triggerLocalSystemNotification(
                            title: "Trip Cancelled ❌",
                            body: "Your trip to \(trip.endLocation) was cancelled by the manager."
                        )
                    }
                }
            }
        }
    }

    func unsubscribeRealtime() {
        realtimeTask?.cancel()
        realtimeTask = nil
        tripsRealtimeTask?.cancel()
        tripsRealtimeTask = nil
    }

    private func triggerLocalSystemNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to dispatch native mock push notification: \(error)")
            }
        }
    }

    private func triggerHapticFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func enqueueBanner(_ notification: AppNotification) {
        bannerQueue.append(notification)
        processBannerQueue()
    }

    private func processBannerQueue() {
        guard !isProcessingQueue else { return }
        guard !bannerQueue.isEmpty else { return }

        isProcessingQueue = true
        let nextBanner = bannerQueue.removeFirst()

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentBanner = nextBanner
            showBanner = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            self.dismissCurrentBanner()
        }
    }

    func dismissCurrentBanner() {
        guard showBanner else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            showBanner = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.currentBanner = nil
            self.isProcessingQueue = false
            self.processBannerQueue()
        }
    }
}

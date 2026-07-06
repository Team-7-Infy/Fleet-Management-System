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
    private var driverId: UUID?
    private var realtimeTask: Task<Void, Never>?
    private var tripsRealtimeTask: Task<Void, Never>?
    let role: NotificationRecipientRole

    @Published var notifications: [AppNotification] = []
    @Published var unreadCount: Int = 0
    @Published var showBanner: Bool = false
    @Published var currentBanner: AppNotification?
    
    private var notifiedTripKeys = Set<String>()

    private var bannerQueue: [AppNotification] = []
    private var localNotifications: [AppNotification] = []
    private var isProcessingQueue = false

    init(notificationService: NotificationServiceProtocol, recipientId: UUID?, driverId: UUID? = nil, role: NotificationRecipientRole = .driver) {
        self.notificationService = notificationService
        self.recipientId = recipientId
        self.driverId = driverId
        self.role = role
    }

    func setRecipientId(_ id: UUID?, driverId: UUID? = nil) {
        guard self.recipientId != id || self.driverId != driverId else { return }
        self.recipientId = id
        self.driverId = driverId
        if realtimeTask != nil {
            subscribeToRealtime()
        }
    }

    private func shouldIncludeNotification(_ notification: AppNotification) -> Bool {
        switch role {
        case .driver:
            return notification.recipientId == recipientId || notification.recipientId == driverId || notification.recipientId == nil
        case .maintenance:
            if let recId = notification.recipientId {
                return recId == recipientId
            }
            let maintenanceTypes = ["work_order_request", "low_stock", "maintenance", "work_order"]
            return maintenanceTypes.contains(notification.type.lowercased())
        case .manager:
            if let recId = notification.recipientId, recId != recipientId {
                return false
            }
            let excludedTypes = ["trip_assignment", "vehicle_assigned", "work_order_assigned", "work_order_assigned_urgent", "maintenance"]
            return !excludedTypes.contains(notification.type.lowercased())
        }
    }

    private func filterNotifications(_ list: [AppNotification]) -> [AppNotification] {
        return list.filter { shouldIncludeNotification($0) }
    }

    func loadNotifications() async {
        do {
            let list = try await notificationService.fetchNotifications(for: recipientId, driverId: driverId)
            self.notifications = mergedNotifications(remote: filterNotifications(list))
            self.unreadCount = self.notifications.filter { !$0.isRead }.count
        } catch {
            print("Failed to load notifications: \(error.localizedDescription)")
        }
    }

    func markAsRead(_ notification: AppNotification) async {
        do {
            try await notificationService.markAsRead(id: notification.id)
            setNotificationRead(id: notification.id)
        } catch {
            if localNotifications.contains(where: { $0.id == notification.id }) {
                setNotificationRead(id: notification.id)
            } else {
                print("Failed to mark notification as read: \(error.localizedDescription)")
            }
        }
    }

    func markAllAsRead() async {
        do {
            try await notificationService.markAllAsRead(for: recipientId, driverId: driverId)
            setAllNotificationsRead()
        } catch {
            if notifications.contains(where: { localNotifications.map(\.id).contains($0.id) }) {
                setAllNotificationsRead()
            } else {
                print("Failed to mark all notifications as read: \(error.localizedDescription)")
            }
        }
    }

    func deleteNotification(_ notification: AppNotification) async {
        do {
            try await notificationService.deleteNotification(id: notification.id)
        } catch {
            print("Failed to delete notification from server: \(error.localizedDescription)")
        }
        await MainActor.run {
            notifications.removeAll { $0.id == notification.id }
            localNotifications.removeAll { $0.id == notification.id }
            unreadCount = notifications.filter { !$0.isRead }.count
        }
    }

    func clearAllNotifications() async {
        guard let userId = recipientId else {
            await MainActor.run {
                notifications.removeAll()
                localNotifications.removeAll()
                unreadCount = 0
            }
            return
        }
        do {
            try await notificationService.clearAllNotifications(for: userId)
        } catch {
            print("Failed to clear all notifications from server: \(error.localizedDescription)")
        }
        await MainActor.run {
            notifications.removeAll()
            localNotifications.removeAll()
            unreadCount = 0
        }
    }

    func addLocalNotification(title: String, message: String, type: String = "system") {
        let notification = AppNotification(
            id: UUID(),
            title: title,
            message: message,
            type: type,
            isRead: false,
            referenceId: nil,
            recipientId: recipientId,
            createdAt: Date.now
        )

        localNotifications.insert(notification, at: 0)
        notifications = mergedNotifications(remote: notifications)
        unreadCount = notifications.filter { !$0.isRead }.count
        triggerHapticFeedback()
        enqueueBanner(notification)

        Task {
            do {
                _ = try await notificationService.createNotification(notification)
            } catch {
                print("Failed to persist local notification: \(error.localizedDescription)")
            }
        }
    }

    private func mergedNotifications(remote: [AppNotification]) -> [AppNotification] {
        let remoteIds = Set(remote.map(\.id))
        return (localNotifications.filter { remoteIds.contains($0.id) == false } + remote)
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func setNotificationRead(id: UUID) {
        if let index = notifications.firstIndex(where: { $0.id == id }) {
            notifications[index].isRead = true
        }
        if let localIndex = localNotifications.firstIndex(where: { $0.id == id }) {
            localNotifications[localIndex].isRead = true
        }
        unreadCount = notifications.filter { !$0.isRead }.count
    }

    private func setAllNotificationsRead() {
        for index in notifications.indices {
            notifications[index].isRead = true
        }
        for index in localNotifications.indices {
            localNotifications[index].isRead = true
        }
        unreadCount = 0
    }

    func subscribeToRealtime() {
        realtimeTask?.cancel()
        realtimeTask = Task {
            let stream = notificationService.subscribeToRealtime(for: recipientId, driverId: driverId)
            for await newNotification in stream {
                guard shouldIncludeNotification(newNotification) else { continue }
                self.notifications.insert(newNotification, at: 0)
                self.unreadCount += 1
                
                triggerHapticFeedback()
                enqueueBanner(newNotification)
                triggerLocalSystemNotification(title: newNotification.title, body: newNotification.message)
            }
        }

        if role == .driver, let dId = driverId {
            tripsRealtimeTask?.cancel()
            tripsRealtimeTask = Task {
                let stream = notificationService.subscribeToTripsRealtime(forDriverId: dId)
                for await trip in stream {
                    // Always reload dashboard for any realtime update
                    NotificationCenter.default.post(name: NSNotification.Name("ReloadTrips"), object: nil)
                    
                    if trip.status == .scheduled || trip.status == .pending {
                        let key = "\(trip.id.uuidString)-assigned"
                        if !notifiedTripKeys.contains(key) {
                            notifiedTripKeys.insert(key)
                            triggerHapticFeedback()
                            triggerLocalSystemNotification(
                                title: "New Trip Assigned 🚚",
                                body: "Route: \(trip.startLocation) to \(trip.endLocation)"
                            )
                        }
                    } else if trip.status == .cancelled {
                        let key = "\(trip.id.uuidString)-cancelled"
                        if !notifiedTripKeys.contains(key) {
                            notifiedTripKeys.insert(key)
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

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            self.dismissCurrentBanner()
        }
    }

    func dismissCurrentBanner() {
        guard showBanner else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            showBanner = false
        }
        
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.3))
            self.currentBanner = nil
            self.isProcessingQueue = false
            self.processBannerQueue()
        }
    }
}

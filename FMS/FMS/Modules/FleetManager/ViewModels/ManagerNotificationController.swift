import Combine
import Foundation

@MainActor
final class ManagerNotificationController: ObservableObject {
    @Published private(set) var notifications: [FleetNotification] = []
    @Published var selectedFilter: FleetNotificationFilter = .all
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: FleetNotificationServiceProtocol
    private var recipientId: UUID?
    private var isShowingSampleNotifications = false
    private let sampleRecipientId = UUID(uuidString: "D130922F-67AB-42F5-AC16-B1D8B0F53101")!

    init(service: FleetNotificationServiceProtocol) {
        self.service = service
    }

    var unreadCount: Int {
        notifications.filter { $0.isRead == false }.count
    }

    func unreadCount(for filter: FleetNotificationFilter) -> Int {
        notifications(for: filter).filter { $0.isRead == false }.count
    }

    func notifications(for filter: FleetNotificationFilter? = nil, searchText: String = "") -> [FleetNotification] {
        let activeFilter = filter ?? selectedFilter
        let filteredByCategory = notifications.filter { notification in
            guard let category = activeFilter.category else { return true }
            return notification.category == category
        }

        let normalizedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedSearch.isEmpty == false else {
            return filteredByCategory
        }

        return filteredByCategory.filter { notification in
            notification.title.localizedCaseInsensitiveContains(normalizedSearch)
                || notification.message.localizedCaseInsensitiveContains(normalizedSearch)
                || notification.category.title.localizedCaseInsensitiveContains(normalizedSearch)
        }
    }

    func load(recipientId: UUID?) async {
        guard let recipientId else {
            notifications = sampleNotifications(for: sampleRecipientId)
            self.recipientId = nil
            isShowingSampleNotifications = true
            return
        }

        self.recipientId = recipientId
        isLoading = true
        defer { isLoading = false }

        do {
            let fetchedNotifications = try await service.fetchNotifications(recipientId: recipientId)
            if fetchedNotifications.isEmpty {
                notifications = sampleNotifications(for: recipientId)
                isShowingSampleNotifications = true
            } else {
                notifications = fetchedNotifications
                isShowingSampleNotifications = false
            }
            errorMessage = nil
        } catch is CancellationError {
            errorMessage = nil
        } catch {
            if notifications.isEmpty {
                notifications = sampleNotifications(for: recipientId)
                isShowingSampleNotifications = true
            }
            errorMessage = error.localizedDescription
        }
    }

    func markRead(_ notification: FleetNotification) async {
        guard notification.isRead == false else { return }

        setLocalReadState(id: notification.id, isRead: true)
        guard isShowingSampleNotifications == false else { return }

        do {
            try await service.markNotificationRead(id: notification.id, isRead: true)
            errorMessage = nil
        } catch {
            setLocalReadState(id: notification.id, isRead: false)
            errorMessage = error.localizedDescription
        }
    }

    func markAllRead() async {
        let category = selectedFilter.category
        let affectedIds = notifications(for: selectedFilter)
            .filter { $0.isRead == false }
            .map(\.id)

        guard affectedIds.isEmpty == false else { return }
        affectedIds.forEach { setLocalReadState(id: $0, isRead: true) }

        guard let recipientId, isShowingSampleNotifications == false else { return }

        do {
            try await service.markAllNotificationsRead(recipientId: recipientId, category: category)
            errorMessage = nil
        } catch {
            affectedIds.forEach { setLocalReadState(id: $0, isRead: false) }
            errorMessage = error.localizedDescription
        }
    }

    private func setLocalReadState(id: UUID, isRead: Bool) {
        guard let index = notifications.firstIndex(where: { $0.id == id }) else { return }
        notifications[index].isRead = isRead
    }

    private func sampleNotifications(for recipientId: UUID) -> [FleetNotification] {
        FleetNotification.sampleNotifications(recipientId: recipientId).map { sample in
            var notification = sample
            if let existing = notifications.first(where: { $0.id == sample.id }) {
                notification.isRead = existing.isRead
            }
            return notification
        }
    }
}

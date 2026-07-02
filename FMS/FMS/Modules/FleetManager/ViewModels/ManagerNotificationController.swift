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
            notifications = []
            self.recipientId = nil
            return
        }

        self.recipientId = recipientId
        isLoading = true
        defer { isLoading = false }

        do {
            notifications = try await service.fetchNotifications(recipientId: recipientId)
            errorMessage = nil
        } catch is CancellationError {
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markRead(_ notification: FleetNotification) async {
        guard notification.isRead == false else { return }

        setLocalReadState(id: notification.id, isRead: true)

        do {
            try await service.markNotificationRead(id: notification.id, isRead: true)
            errorMessage = nil
        } catch {
            setLocalReadState(id: notification.id, isRead: false)
            errorMessage = error.localizedDescription
        }
    }

    func markAllRead() async {
        guard let recipientId else { return }
        let category = selectedFilter.category
        let affectedIds = notifications(for: selectedFilter)
            .filter { $0.isRead == false }
            .map(\.id)

        guard affectedIds.isEmpty == false else { return }
        affectedIds.forEach { setLocalReadState(id: $0, isRead: true) }

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
}

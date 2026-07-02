import Foundation

protocol FleetNotificationServiceProtocol: Sendable {
    func fetchNotifications(recipientId: UUID) async throws -> [FleetNotification]
    func markNotificationRead(id: UUID, isRead: Bool) async throws
    func markAllNotificationsRead(recipientId: UUID, category: FleetNotificationCategory?) async throws
}

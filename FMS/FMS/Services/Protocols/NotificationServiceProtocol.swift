import Foundation

protocol NotificationServiceProtocol: AnyObject, Sendable {
    func fetchNotifications(for recipientId: UUID?) async throws -> [AppNotification]
    func markAsRead(id: UUID) async throws
    func markAllAsRead(for recipientId: UUID?) async throws
    func subscribeToRealtime(for recipientId: UUID?) -> AsyncStream<AppNotification>
    func subscribeToTripsRealtime(forDriverId driverId: UUID) -> AsyncStream<Trip>
}

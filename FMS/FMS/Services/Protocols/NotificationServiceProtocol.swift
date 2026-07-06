import Foundation

protocol NotificationServiceProtocol: AnyObject, Sendable {
    func fetchNotifications(for recipientId: UUID?, driverId: UUID?) async throws -> [AppNotification]
    func createNotification(_ notification: AppNotification) async throws -> AppNotification
    func markAsRead(id: UUID) async throws
    func markAllAsRead(for recipientId: UUID?, driverId: UUID?) async throws
    func deleteNotification(id: UUID) async throws
    func clearAllNotifications(for userId: UUID) async throws
    func subscribeToRealtime(for recipientId: UUID?, driverId: UUID?) -> AsyncStream<AppNotification>
    func subscribeToTripsRealtime(forDriverId driverId: UUID) -> AsyncStream<Trip>
}

extension NotificationServiceProtocol {
    func fetchNotifications(for recipientId: UUID?) async throws -> [AppNotification] {
        try await fetchNotifications(for: recipientId, driverId: nil)
    }
    
    func markAllAsRead(for recipientId: UUID?) async throws {
        try await markAllAsRead(for: recipientId, driverId: nil)
    }
    
    func subscribeToRealtime(for recipientId: UUID?) -> AsyncStream<AppNotification> {
        subscribeToRealtime(for: recipientId, driverId: nil)
    }
}

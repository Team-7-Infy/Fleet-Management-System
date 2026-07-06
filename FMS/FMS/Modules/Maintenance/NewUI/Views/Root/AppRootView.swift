import SwiftUI

struct AppRootView: View {
    let dependencies: AppDependencyContainer
    let notificationService: NotificationServiceProtocol

    var body: some View {
        RootTabView(dependencies: dependencies, notificationService: notificationService)
            .tint(AppColor.brand)
    }
}

#Preview {
    let mock = PreviewNotificationService()
    AppRootView(dependencies: .mock(), notificationService: mock)
}

private actor PreviewNotificationService: NotificationServiceProtocol {
    func fetchNotifications(for recipientId: UUID?, driverId: UUID?) async throws -> [AppNotification] { [] }
    func createNotification(_ notification: AppNotification) async throws -> AppNotification { notification }
    func markAsRead(id: UUID) async throws {}
    func markAllAsRead(for recipientId: UUID?, driverId: UUID?) async throws {}
    func subscribeToRealtime(for recipientId: UUID?, driverId: UUID?) -> AsyncStream<AppNotification> {
        AsyncStream { $0.finish() }
    }
    func subscribeToTripsRealtime(forDriverId driverId: UUID) -> AsyncStream<Trip> {
        AsyncStream { $0.finish() }
    }
}

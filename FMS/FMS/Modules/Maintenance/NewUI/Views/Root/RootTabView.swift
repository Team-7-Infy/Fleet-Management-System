import SwiftUI

struct RootTabView: View {
    let dependencies: AppDependencyContainer
    let onLogout: () -> Void
    let notificationService: NotificationServiceProtocol
    @State private var selectedTab: AppTab = .dashboard
    @StateObject private var dashboardNavigation = TabNavigationState()

    init(dependencies: AppDependencyContainer, coordinator: NavigationCoordinator? = nil, onLogout: @escaping () -> Void = {}, notificationService: NotificationServiceProtocol) {
        self.dependencies = dependencies
        self.onLogout = onLogout
        self.notificationService = notificationService
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $dashboardNavigation.path) {
                MPDashboardView(dependencies: dependencies, navigation: dashboardNavigation, onLogout: onLogout, notificationService: notificationService)
                    .navigationDestination(for: AppRoute.self) { route in
                        RouteViewFactory.view(for: route, dependencies: dependencies, navigation: dashboardNavigation)
                    }
            }
            .tabItem {
                Label(AppTab.dashboard.title, systemImage: AppTab.dashboard.systemImage)
            }
            .tag(AppTab.dashboard)

            NavigationStack {
                InventoryView()
            }
            .tabItem {
                Label(AppTab.inventory.title, systemImage: AppTab.inventory.systemImage)
            }
            .tag(AppTab.inventory)
        }
    }
}

#Preview {
    let mock = PreviewNotificationService()
    RootTabView(dependencies: .mock(), notificationService: mock)
}

private actor PreviewNotificationService: NotificationServiceProtocol {
    func fetchNotifications(for recipientId: UUID?) async throws -> [AppNotification] { [] }
    func markAsRead(id: UUID) async throws {}
    func markAllAsRead(for recipientId: UUID?) async throws {}
    func subscribeToRealtime(for recipientId: UUID?) -> AsyncStream<AppNotification> {
        AsyncStream { $0.finish() }
    }
    func subscribeToTripsRealtime(forDriverId driverId: UUID) -> AsyncStream<Trip> {
        AsyncStream { $0.finish() }
    }
}

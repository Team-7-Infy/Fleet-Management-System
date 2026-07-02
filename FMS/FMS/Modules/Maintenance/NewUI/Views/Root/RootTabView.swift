import SwiftUI

struct RootTabView: View {
    let dependencies: AppDependencyContainer
    let onLogout: () -> Void
    @State private var selectedTab: AppTab = .dashboard
    @StateObject private var dashboardNavigation = TabNavigationState()
    @StateObject private var myJobsNavigation = TabNavigationState()

    init(dependencies: AppDependencyContainer, coordinator: NavigationCoordinator? = nil, onLogout: @escaping () -> Void = {}) {
        self.dependencies = dependencies
        self.onLogout = onLogout
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $dashboardNavigation.path) {
                MPDashboardView(dependencies: dependencies, navigation: dashboardNavigation, onLogout: onLogout)
                    .navigationDestination(for: AppRoute.self) { route in
                        RouteViewFactory.view(for: route, dependencies: dependencies, navigation: dashboardNavigation)
                    }
            }
            .tabItem {
                Label(AppTab.dashboard.title, systemImage: AppTab.dashboard.systemImage)
            }
            .tag(AppTab.dashboard)

            NavigationStack(path: $myJobsNavigation.path) {
                MyJobsView(dependencies: dependencies, navigation: myJobsNavigation)
                    .navigationDestination(for: AppRoute.self) { route in
                        RouteViewFactory.view(for: route, dependencies: dependencies, navigation: myJobsNavigation)
                    }
            }
            .tabItem {
                Label(AppTab.myJobs.title, systemImage: AppTab.myJobs.systemImage)
            }
            .tag(AppTab.myJobs)

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
    RootTabView(dependencies: .mock())
}

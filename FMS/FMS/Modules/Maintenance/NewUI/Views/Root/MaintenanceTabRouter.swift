import SwiftUI
import Supabase

struct MaintenanceTabRouter: View {
    let onLogout: () -> Void
    let services: AppServices
    @State private var dependencies: AppDependencyContainer
    @StateObject private var coordinator = NavigationCoordinator()
    @StateObject private var notificationViewModel: NotificationViewModel

    init(services: AppServices, onLogout: @escaping () -> Void) {
        self.onLogout = onLogout
        self.services = services
        _dependencies = State(initialValue: AppDependencyContainer.supabase(client: services.supabase.client))
        _notificationViewModel = StateObject(
            wrappedValue: NotificationViewModel(
                notificationService: services.notificationService,
                recipientId: nil,
                role: .maintenance
            )
        )
    }

    var body: some View {
        RootTabView(
            dependencies: dependencies,
            notificationViewModel: notificationViewModel,
            coordinator: coordinator,
            onLogout: onLogout
        )
    }
}

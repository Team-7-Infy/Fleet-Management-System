import SwiftUI
import Supabase

struct MaintenanceTabRouter: View {
    let onLogout: () -> Void
    let supabaseClient: SupabaseClient
    let notificationService: NotificationServiceProtocol
    @State private var dependencies: AppDependencyContainer
    @StateObject private var coordinator = NavigationCoordinator()

    init(onLogout: @escaping () -> Void, supabaseClient: SupabaseClient, notificationService: NotificationServiceProtocol) {
        self.onLogout = onLogout
        self.supabaseClient = supabaseClient
        self.notificationService = notificationService
        _dependencies = State(initialValue: AppDependencyContainer.supabase(client: supabaseClient))
    }

    var body: some View {
        RootTabView(dependencies: dependencies, coordinator: coordinator, onLogout: onLogout, notificationService: notificationService)
    }
}

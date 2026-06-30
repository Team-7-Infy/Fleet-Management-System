import SwiftUI
import Supabase

struct MaintenanceTabRouter: View {
    let onLogout: () -> Void
    let supabaseClient: SupabaseClient
    @State private var dependencies: AppDependencyContainer
    @StateObject private var coordinator = NavigationCoordinator()

    init(onLogout: @escaping () -> Void, supabaseClient: SupabaseClient) {
        self.onLogout = onLogout
        self.supabaseClient = supabaseClient
        _dependencies = State(initialValue: AppDependencyContainer.supabase(client: supabaseClient))
    }

    var body: some View {
        RootTabView(dependencies: dependencies, coordinator: coordinator, onLogout: onLogout)
    }
}

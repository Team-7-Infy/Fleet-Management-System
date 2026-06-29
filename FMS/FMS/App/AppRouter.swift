import SwiftUI

@MainActor
final class AppServices {
    let supabase: SupabaseService
    let authService: AuthService
    let vehicleService: VehicleService
    let tripService: TripService
    let maintenanceService: MaintenanceService
    let inventoryService: InventoryService
    let userManagementService: UserManagementService

    init() {
        let supabase = SupabaseService()
        self.supabase = supabase
        authService = AuthService(supabase: supabase)
        vehicleService = VehicleService(supabase: supabase)
        tripService = TripService(supabase: supabase)
        maintenanceService = MaintenanceService(supabase: supabase)
        inventoryService = InventoryService(supabase: supabase)
        userManagementService = UserManagementService(supabase: supabase)
    }
}

private enum AppScreen {
    case splash
    case login
    case firstTimeSetup(user: User)
    case fleetManager
    case maintenancePersonnel
    case driver(user: User)
}

struct AppRouter: View {
    @State private var services = AppServices()
    @State private var screen: AppScreen = .splash

    var body: some View {
        switch screen {
        case .splash:
            SplashView(authService: services.authService) { user in
                if let user {
                    screen = route(for: user)
                } else {
                    screen = .login
                }
            }

        case .login:
            NavigationStack {
                LoginView(authService: services.authService) { user in
                    if let user {
                        screen = route(for: user)
                    } else {
                        screen = .login
                    }
                }
            }

        case .firstTimeSetup(let user):
            NavigationStack {
                FirstTimeSetupView(authService: services.authService, user: user, onComplete: { activatedUser in
                    screen = route(for: activatedUser)
                }, onLogout: logout)
            }

        case .fleetManager:
            FleetManagerDashboardView(services: services, onLogout: logout)

        case .maintenancePersonnel:
            MaintenanceTabRouter(onLogout: logout, supabaseClient: services.supabase.client)

        case .driver(let user):
            DriverDashboardView(services: services, user: user, onLogout: logout)
        }
    }

    private func route(for user: User) -> AppScreen {
        if user.firstTimeLogin {
            return .firstTimeSetup(user: user)
        }
        switch user.role {
        case .driver:
            return .driver(user: user)
        case .maintenancePersonnel:
            return .maintenancePersonnel
        case .fleetManager:
            return .fleetManager
        }
    }

    private func logout() {
        Task {
            do {
                try await services.authService.signOut()
            } catch {
                print("Logout failed: \(error.localizedDescription)")
            }
        }
        screen = .login
    }
}

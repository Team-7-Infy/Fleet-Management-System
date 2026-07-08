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
    let fleetNotificationService: FleetNotificationService
    let notificationService: NotificationService
    let inspectionService: InspectionService
    let expenseService: ExpenseService
    let workOrderAssignmentService: WorkOrderAssignmentService

    init() {
        let supabase = SupabaseService()
        self.supabase = supabase
        authService = AuthService(supabase: supabase)
        vehicleService = VehicleService(supabase: supabase)
        tripService = TripService(supabase: supabase)
        maintenanceService = MaintenanceService(supabase: supabase)
        inventoryService = InventoryService(supabase: supabase)
        userManagementService = UserManagementService(supabase: supabase)
        fleetNotificationService = FleetNotificationService(supabase: supabase)
        notificationService = NotificationService(supabase: supabase)
        inspectionService = InspectionService(supabase: supabase)
        expenseService = ExpenseService(supabase: supabase)
        workOrderAssignmentService = WorkOrderAssignmentService(
            userManagementService: userManagementService,
            maintenanceService: maintenanceService
        )

        ThresholdStore.shared.configure(supabase: supabase)
    }
}

private enum AppScreen {
    case login(assets: LoginAssets?)
    case firstTimeSetup(user: User)
    case fleetManager
    case maintenancePersonnel
    case driver(user: User)
}

struct AppRouter: View {
    @State private var services = AppServices()

    // The real destination — defaults to login so it's ready behind the splash
    @State private var screen: AppScreen = .login(assets: nil)

    // Splash overlay state
    @State private var splashVisible = true
    @State private var splashOpacity: Double = 1.0

    var body: some View {
        ZStack {
            // ── Real content (always rendered, visible once splash fades) ──
            contentView

            // ── Splash overlay on top ─────────────────────────────────────
            if splashVisible {
                SplashView(authService: services.authService) { user, assets in
                    // Set real destination before fading so it's ready underneath
                    if let user {
                        screen = route(for: user)
                    } else {
                        screen = .login(assets: assets)
                    }

                    // Fade the splash out over the already-rendered content
                    withAnimation(.easeInOut(duration: 0.4)) {
                        splashOpacity = 0
                    }
                    Task {
                        try? await Task.sleep(for: .seconds(0.45))
                        splashVisible = false
                    }
                }
                .opacity(splashOpacity)
                .ignoresSafeArea()
            }
        }
    }

    // MARK: - Content beneath the splash

    @ViewBuilder
    private var contentView: some View {
        switch screen {
        case .login(let assets):
            NavigationStack {
                LoginView(authService: services.authService, preloadedAssets: assets) { user in
                    if let user {
                        screen = route(for: user)
                    } else {
                        screen = .login(assets: nil)
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
            MaintenanceTabRouter(onLogout: logout, supabaseClient: services.supabase.client, notificationService: services.notificationService)

        case .driver(let user):
            DriverDashboardView(services: services, user: user, onLogout: logout)
        }
    }

    // MARK: - Helpers

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
        screen = .login(assets: nil)
    }
}

#Preview {
    AppRouter()
}

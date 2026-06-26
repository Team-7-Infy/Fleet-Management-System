import SwiftUI
import Supabase
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

struct AppRouter: View {
    @State private var services = AppServices()

    var body: some View {
        FleetManagerDashboardView(services: services)
    }
}

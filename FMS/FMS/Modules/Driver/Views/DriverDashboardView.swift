import SwiftUI

struct DriverDashboardView: View {
    let services: AppServices
    let user: User
    let onLogout: () -> Void

    @StateObject private var locationService = LocationManager()
    @State private var showingProfile = false
    @State private var trips: [Trip] = []
    @State private var vehicles: [Vehicle] = []
    @State private var driver: Driver?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading dashboard...")
                    .task { await loadData() }
            } else {
                DashboardView(
                    showingProfile: $showingProfile,
                    services: services,
                    user: user,
                    driver: driver,
                    trips: trips,
                    vehicles: vehicles,
                    onRefreshData: loadData
                )
                .environmentObject(locationService)
                .environmentObject(LocalDataStore.shared)
                .sheet(isPresented: $showingProfile) {
                    ProfileHubView(
                        services: services,
                        driver: driver,
                        user: user,
                        onLogout: onLogout
                    )
                }
            }
        }
    }

    private func loadData() async {
        do {
            async let fetchedDrivers = services.userManagementService.fetchDrivers()
            let d = try await fetchedDrivers
            guard let matchedDriver = d.first(where: { $0.userId == user.id }) else {
                await MainActor.run { isLoading = false }
                return
            }

            async let fetchedTrips = services.tripService.fetchTrips(forDriverId: matchedDriver.id)
            async let fetchedVehicles = services.vehicleService.fetchVehicles(forDriverId: matchedDriver.id)

            let (t, v) = try await (fetchedTrips, fetchedVehicles)

            await MainActor.run {
                trips = t
                vehicles = v
                driver = matchedDriver
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

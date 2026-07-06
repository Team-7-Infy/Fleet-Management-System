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
    @State private var realtimeTask: Task<Void, Never>? = nil

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
                    onLogout: onLogout,
                    onRefreshData: loadData
                )
                .environmentObject(locationService)
                .environmentObject(LocalDataStore.shared)
                .onAppear {
                    if let driverId = driver?.id {
                        startRealtimeTrips(for: driverId)
                    }
                }
                .onDisappear {
                    realtimeTask?.cancel()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ReloadTrips"))) { _ in
                    if let driverId = driver?.id {
                        Task {
                            await reloadTripsAndVehicles(for: driverId)
                        }
                    }
                }
            }
        }
    }

    private func startRealtimeTrips(for driverId: UUID) {
        realtimeTask?.cancel()
        realtimeTask = Task {
            let stream = services.tripService.subscribeToTrips(forDriverId: driverId)
            for await _ in stream {
                await reloadTripsAndVehicles(for: driverId)
            }
        }
    }

    private func reloadTripsAndVehicles(for driverId: UUID) async {
        do {
            let fetchedTrips = try await services.tripService.fetchTrips(forDriverId: driverId)
            let fetchedVehicles = try await services.vehicleService.fetchVehicles()
            await MainActor.run {
                self.trips = fetchedTrips
                self.vehicles = fetchedVehicles
            }
        } catch {
            print("Failed to reload realtime trips/vehicles: \(error)")
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
            async let fetchedVehicles = services.vehicleService.fetchVehicles()

            let (t, v) = try await (fetchedTrips, fetchedVehicles)

            await MainActor.run {
                trips = t
                vehicles = v
                driver = matchedDriver
                isLoading = false
                startRealtimeTrips(for: matchedDriver.id)
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

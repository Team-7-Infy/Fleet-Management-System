import SwiftUI

struct DriverDashboardView: View {
    let services: AppServices
    let onLogout: () -> Void
    @State private var user: User

    init(services: AppServices, user: User, onLogout: @escaping () -> Void) {
        self.services = services
        self._user = State(initialValue: user)
        self.onLogout = onLogout
    }

    @StateObject private var locationService = LocationManager()
    @State private var showingProfile = false
    @State private var trips: [Trip] = []
    @State private var vehicles: [Vehicle] = []
    @State private var driver: Driver?
    @State private var isLoading = true
    @State private var realtimeTask: Task<Void, Never>? = nil
    @State private var refreshTimer: Timer? = nil

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
                        Task { await reloadTripsAndVehicles(for: driverId) }
                        startRealtimeTrips(for: driverId)
                        startRefreshTimer(for: driverId)
                    }
                }
                .onDisappear {
                    realtimeTask?.cancel()
                    refreshTimer?.invalidate()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ReloadTrips"))) { _ in
                    if let driverId = driver?.id {
                        Task {
                            await reloadTripsAndVehicles(for: driverId)
                        }
                    }
                }
                .onChange(of: showingProfile) { _, isShowing in
                    if !isShowing {
                        Task { await reloadCurrentUser() }
                    }
                }
            }
        }
    }

    private func startRefreshTimer(for driverId: UUID) {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task { await reloadTripsAndVehicles(for: driverId) }
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

    private func syncInspectionsFromDatabase(for trips: [Trip]) async {
        for trip in trips {
            do {
                let inspections = try await services.inspectionService.fetchInspections(tripId: trip.id)
                let hasPreTrip = inspections.contains { $0.type == "pre_trip" && $0.status == .passed }
                await MainActor.run {
                    if hasPreTrip {
                        LocalDataStore.shared.markTripInspected(trip.id.uuidString, vehicleId: trip.vehicleId)
                    } else {
                        LocalDataStore.shared.unmarkTripInspected(trip.id.uuidString)
                    }
                }
            } catch {
                print("Failed to sync inspections for trip \(trip.id): \(error)")
            }
        }
    }

    private func reloadTripsAndVehicles(for driverId: UUID) async {
        do {
            let fetchedTrips = try await services.tripService.fetchTrips(forDriverId: driverId)
            let fetchedVehicles = try await services.vehicleService.fetchVehicles()
            await syncInspectionsFromDatabase(for: fetchedTrips)
            await MainActor.run {
                self.trips = fetchedTrips
                self.vehicles = fetchedVehicles
            }
        } catch {
            print("Failed to reload realtime trips/vehicles: \(error)")
        }
    }

    private func reloadCurrentUser() async {
        do {
            let allUsers = try await services.userManagementService.fetchUsers()
            if let refreshed = allUsers.first(where: { $0.id == user.id }) {
                await MainActor.run { user = refreshed }
            }
        } catch {}
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

            LocalDataStore.shared.currentDriverId = matchedDriver.id
            Task { await LocalDataStore.shared.loadFuelHistoryFromDatabase(driverId: matchedDriver.id) }
            await syncInspectionsFromDatabase(for: t)

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

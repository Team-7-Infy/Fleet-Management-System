import Combine
import SwiftUI

struct DriverDashboardView: View {
    let services: AppServices
    let user: User
    let onLogout: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var locationManager = DriverLocationManager()
    @State private var driver: Driver?
    @State private var trips: [Trip] = []
    @State private var vehicles: [Vehicle] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedTripForReject: Trip?
    @State private var showPreTripAlert = false
    @State private var showPostTripAlert = false
    @State private var tripToStart: Trip?
    @State private var tripToEnd: Trip?
    @State private var showNavigation = false
    @State private var navigatingTrip: Trip?
    @State private var isShowingProfile = false

    private var pendingTrips: [Trip] {
        driverTrips.filter { $0.status == .pending }
    }

    private var activeTrips: [Trip] {
        driverTrips.filter { $0.status == .accepted || $0.status == .inProgress }
    }

    private var completedTrips: [Trip] {
        driverTrips.filter { $0.status == .completed }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    assignedTripsSection

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(FleetPalette.danger)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(FleetPalette.danger.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .padding()
            }
            .fleetScreenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await loadData(isRefresh: true) }
            .task { await loadData() }
            .onReceive(Timer.publish(every: 15, on: .main, in: .common).autoconnect()) { _ in
                Task { await loadData(isRefresh: true) }
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { await loadData(isRefresh: true) }
            }
            .sheet(item: $selectedTripForReject) { trip in
                RejectTripSheet(trip: trip) { reason in
                    Task { await rejectTrip(trip, reason: reason) }
                }
            }
            .alert("Start Pre-Trip Inspection", isPresented: $showPreTripAlert) {
                Button("Cancel", role: .cancel) { tripToStart = nil }
                Button("Start Trip") {
                    if let trip = tripToStart {
                        Task { await startTrip(trip) }
                    }
                }
            } message: {
                Text("Please complete a pre-trip inspection before starting. Check tires, lights, fuel, and brakes.")
            }
            .alert("End Post-Trip Inspection", isPresented: $showPostTripAlert) {
                Button("Cancel", role: .cancel) { tripToEnd = nil }
                Button("End Trip", role: .destructive) {
                    if let trip = tripToEnd {
                        Task { await endTrip(trip) }
                    }
                }
            } message: {
                Text("Please complete a post-trip inspection before ending. Report any issues.")
            }
            .navigationDestination(isPresented: $showNavigation) {
                if let trip = navigatingTrip {
                    TripNavigationView(
                        trip: trip,
                        tripService: services.tripService,
                        locationManager: locationManager,
                        onEndTrip: {
                            Task { await endTrip(trip) }
                        }
                    )
                }
            }
            .sheet(isPresented: $isShowingProfile) {
                NavigationStack {
                    ProfileView(
                        driver: driver ?? Driver(id: UUID(), licenceNum: "", vehicleType: "", status: .active, userId: user.id),
                        user: user,
                        completedTrips: completedTrips,
                        onLogout: onLogout
                    )
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                isShowingProfile = false
                            }
                            .fontWeight(.semibold)
                        }
                    }
                }
            }
        }
    }

    private var accountButton: some View {
        Button {
            isShowingProfile = true
        } label: {
            if let avatarUrl = user.avatarUrl,
               let imageURL = URL(string: avatarUrl) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 48, height: 48)
                            .clipShape(Circle())
                    default:
                        accountFallbackIcon
                    }
                }
            } else {
                accountFallbackIcon
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Account")
    }

    private var accountFallbackIcon: some View {
        Image(systemName: FleetIcon.account)
            .resizable()
            .scaledToFit()
            .frame(width: 48, height: 48)
            .foregroundStyle(FleetPalette.primary)
            .background(Circle().fill(Color.white))
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Good \(timeOfDay), \(user.fName)")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(FleetPalette.textPrimary)
                Text("You have \(pendingTrips.count) trip\(pendingTrips.count == 1 ? "" : "s") awaiting action")
                    .font(.subheadline)
                    .foregroundStyle(FleetPalette.textSecondary)
            }
            Spacer()
            accountButton
        }
    }

    private var assignedTripsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else if driverTrips.isEmpty {
                GlassPanel {
                    EmptyStateView(
                        title: "No Trips Assigned",
                        message: "You don't have any trips yet. They will appear here once the fleet manager assigns them.",
                        systemImage: "road.lanes"
                    )
                }
            } else {
                if !pendingTrips.isEmpty {
                    tripGroup(title: "Pending Action", trips: pendingTrips, tint: FleetPalette.warning)
                }

                if !activeTrips.isEmpty {
                    tripGroup(title: "Active", trips: activeTrips, tint: FleetPalette.primary)
                }

                if !completedTrips.isEmpty {
                    tripGroup(title: "Completed", trips: completedTrips, tint: FleetPalette.success)
                }
            }
        }
    }

    private func tripGroup(title: String, trips: [Trip], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.title3.weight(.heavy))
                .foregroundStyle(Color(hex: 0x607086))
                .padding(.horizontal, 2)

            LazyVStack(spacing: 14) {
                ForEach(trips) { trip in
                    TripCardView(
                        trip: trip,
                        vehicle: vehicle(for: trip.vehicleId),
                        onAccept: { Task { await acceptTrip(trip) } },
                        onReject: {
                            selectedTripForReject = trip
                        },
                        onStart: {
                            tripToStart = trip
                            showPreTripAlert = true
                        },
                        onEnd: {
                            tripToEnd = trip
                            showPostTripAlert = true
                        }
                    )
                }
            }
        }
    }

    private var driverTrips: [Trip] {
        guard let driver else { return [] }
        return trips.filter { $0.driverId == driver.id }
            .sorted { $0.startTime > $1.startTime }
    }

    private var hasRejectionPending: Bool {
        driverTrips.contains { $0.status == .rejectionPending }
    }

    private func vehicle(for id: UUID) -> Vehicle? {
        vehicles.first { $0.id == id }
    }

    private func loadData(isRefresh: Bool = false) async {
        if !isRefresh || trips.isEmpty {
            isLoading = true
        }
        defer { isLoading = false }

        do {
            async let fetchedDrivers = services.userManagementService.fetchDrivers()
            async let fetchedTrips = services.tripService.fetchTrips()
            async let fetchedVehicles = services.vehicleService.fetchVehicles()

            let (allDrivers, allTrips, allVehicles) = try await (fetchedDrivers, fetchedTrips, fetchedVehicles)
            driver = allDrivers.first { $0.userId == user.id }
            trips = allTrips
            vehicles = allVehicles
            errorMessage = nil
        } catch is CancellationError {
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func acceptTrip(_ trip: Trip) async {
        guard !hasRejectionPending else {
            errorMessage = "Cannot accept while a rejection request is pending review."
            return
        }
        if await updateStatus(trip, status: .accepted) {
            await loadData(isRefresh: true)
        }
    }

    private func rejectTrip(_ trip: Trip, reason: String) async {
        if await updateStatus(trip, status: .rejectionPending, rejectionReason: reason) {
            await loadData(isRefresh: true)
        }
    }

    private func startTrip(_ trip: Trip) async {
        guard !hasRejectionPending else {
            errorMessage = "Cannot start while a rejection request is pending review."
            return
        }
        if await updateStatus(trip, status: .inProgress) {
            navigatingTrip = trip
            showNavigation = true
            await loadData(isRefresh: true)
        }
    }

    private func endTrip(_ trip: Trip) async {
        if await updateStatus(trip, status: .completed) {
            try? await services.vehicleService.unassignDriver(vehicleId: trip.vehicleId)
            navigatingTrip = nil
            showNavigation = false
            await loadData(isRefresh: true)
        }
    }

    @discardableResult
    private func updateStatus(_ trip: Trip, status: TripStatus, rejectionReason: String? = nil) async -> Bool {
        do {
            if let reason = rejectionReason {
                try await services.tripService.updateTripStatus(id: trip.id, status: status, rejectionReason: reason)
            } else {
                try await services.tripService.updateTripStatus(id: trip.id, status: status)
            }
            if let index = trips.firstIndex(where: { $0.id == trip.id }) {
                trips[index].status = status
                trips[index].rejectionReason = rejectionReason
            }
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private var timeOfDay: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Morning"
        case 12..<17: return "Afternoon"
        default: return "Evening"
        }
    }
}

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
                VStack(alignment: .leading, spacing: 24) {
                    header
                    
                    quickActions
                    
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    } else {
                        if let activeTrip = activeTrips.first {
                            activeTripCard(trip: activeTrip)
                        }
                        
                        if let pendingTrip = pendingTrips.first {
                            safetyBlock(trip: pendingTrip)
                        } else if activeTrips.isEmpty && pendingTrips.isEmpty {
                            EmptyStateView(
                                title: "No Trips Assigned",
                                message: "You don't have any trips yet. They will appear here once the fleet manager assigns them.",
                                systemImage: "road.lanes"
                            )
                        }
                        
                        // Remaining trips if any (beyond the first active/pending shown)
                        let remainingActive = activeTrips.dropFirst()
                        let remainingPending = pendingTrips.dropFirst()
                        
                        if !remainingActive.isEmpty || !remainingPending.isEmpty || !completedTrips.isEmpty {
                            Text("Other Trips")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(FleetPalette.textPrimary)
                                .padding(.top, 8)
                            
                            if !remainingPending.isEmpty {
                                tripGroup(trips: Array(remainingPending))
                            }
                            if !remainingActive.isEmpty {
                                tripGroup(trips: Array(remainingActive))
                            }
                            if !completedTrips.isEmpty {
                                tripGroup(trips: completedTrips)
                            }
                        }
                    }

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
            .background(Color(hex: 0xF4F5F9).ignoresSafeArea())
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

    private var header: some View {
        HStack {
            Text("Home")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.black)
            Spacer()
        }
        .padding(.top, 10)
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.black)
            
            HStack(spacing: 12) {
                quickActionCard(title: "Logbook", iconName: "book.pages.fill", tintColor: Color.purple)
                quickActionCard(title: "Fuel", iconName: "fuelpump.fill", tintColor: Color.orange)
                quickActionCard(title: "SOS", iconName: "light.beacon.max.fill", tintColor: Color.red)
            }
        }
    }
    
    private func quickActionCard(title: String, iconName: String, tintColor: Color) -> some View {
        Button(action: {}) {
            VStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: 24))
                    .foregroundStyle(tintColor)
                
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.black)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func activeTripCard(trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text(trip.status == .inProgress ? "ON ROUTE" : "ACCEPTED")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.2))
                .clipShape(Capsule())
                
                Spacer()
                
                Text(Date().formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Next Stop")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                
                Text(trip.endLocation)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                Text("Destination") // Placeholder sub-text
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }
            
            // Progress Bar Placeholder
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.black.opacity(0.2))
                    .frame(height: 6)
                
                Capsule()
                    .fill(Color.white)
                    .frame(width: 140, height: 6)
            }
            
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ETA")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                    Text(trip.startTime, style: .time)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer()
                VStack(alignment: .center, spacing: 4) {
                    Text("REMAINING")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                    Text("2h 15m") // Mocked, ideally from trip data
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("DISTANCE")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                    Text("24.5 km") // Mocked, ideally from trip data
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            
            Button {
                if trip.status == .inProgress {
                    navigatingTrip = trip
                    showNavigation = true
                } else {
                    tripToStart = trip
                    showPreTripAlert = true
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                    Text(trip.status == .inProgress ? "Open Navigation" : "Start Trip")
                }
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            
            if trip.status == .inProgress {
                Button {
                    tripToEnd = trip
                    showPostTripAlert = true
                } label: {
                    Text("End Trip")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(hex: 0x0A66C2), Color(hex: 0x2244CC)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color(hex: 0x0A66C2).opacity(0.3), radius: 15, x: 0, y: 10)
    }

    private func safetyBlock(trip: Trip) -> some View {
        Button(action: {
            tripToStart = trip
            showPreTripAlert = true
        }) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.red.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.red)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("SAFETY BLOCK")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.red)
                    
                    Text("Pre-Trip Inspection Required")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.black)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.gray.opacity(0.5))
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func tripGroup(trips: [Trip]) -> some View {
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
}

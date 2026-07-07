import SwiftUI
import Combine

struct DashboardView: View {
    @Binding var showingProfile: Bool

    let services: AppServices
    let user: User
    let driver: Driver?
    let trips: [Trip]
    let vehicles: [Vehicle]
    let onLogout: () -> Void
    var onRefreshData: (() async -> Void)? = nil

    @StateObject private var viewModel: DashboardViewModel
    @StateObject private var notificationViewModel: NotificationViewModel
    @EnvironmentObject var locationService: LocationManager
    @EnvironmentObject var localStore: LocalDataStore

    init(showingProfile: Binding<Bool>, services: AppServices, user: User, driver: Driver?, trips: [Trip], vehicles: [Vehicle], onLogout: @escaping () -> Void, onRefreshData: (() async -> Void)? = nil) {
        self._showingProfile = showingProfile
        self.services = services
        self.user = user
        self.driver = driver
        self.trips = trips
        self.vehicles = vehicles
        self.onLogout = onLogout
        self.onRefreshData = onRefreshData
        self._viewModel = StateObject(wrappedValue: DashboardViewModel(services: services, driver: driver, user: user))
        self._notificationViewModel = StateObject(
            wrappedValue: NotificationViewModel(
                notificationService: services.notificationService,
                recipientId: user.id,
                driverId: driver?.id,
                role: .driver
            )
        )
    }

    // MARK: - Navigation States
    @State private var showingSOSAlert = false
    @State private var showingFuelSheet = false
    @State private var showingLogbookSheet = false
    @State private var selectedTripToStart: String? = nil
    @State private var showingInspectionSheet = false
    @State private var showingActiveNavigation = false
    @State private var activeTripForNavigation: Trip? = nil
    @State private var showingTripDetailsSheet = false
    @State private var showingNotifications = false

    @State private var tripToReject: Trip?
    @State private var selectedScheduledTrip: Trip?
    
    // Post-Trip Inspection & Success States
    @State private var showingPostTripInspection = false
    @State private var selectedTripForPostInspection: Trip? = nil
    @State private var showingTripSuccess = false
    @State private var successDistance: Double = 0.0
    @State private var successDuration: Int = 0
    @State private var completedTripForSuccess: Trip? = nil

    var body: some View {
        // 1. Live Trip (if available)
        let liveTrip = trips.first(where: { $0.status == .inProgress })

        // 2. All Scheduled Trips
        let allScheduled = trips.filter {
            $0.status == .accepted || $0.status == .pending || $0.status == .scheduled
        }.sorted { $0.startTime < $1.startTime }

        // The nearest accepted or inspection-eligible Scheduled Trip (top card if no Live Trip exists)
        let nearestScheduledTrip = liveTrip == nil ? allScheduled.first(where: {
            $0.status == .accepted ||
            (($0.status == .scheduled || $0.status == .pending) && Date() >= $0.startTime.addingTimeInterval(-3 * 3600))
        }) : nil

        // Is Pre-Trip Inspection enabled for the nearest Scheduled Trip?
        let isInspectionEnabled: Bool = {
            if let nearest = nearestScheduledTrip {
                let threeHoursBefore = nearest.startTime.addingTimeInterval(-3 * 3600)
                return Date() >= threeHoursBefore
            }
            return false
        }()

        // Remaining scheduled trips for the section list below
        let remainingScheduled = allScheduled.filter { trip in
            if let nearest = nearestScheduledTrip {
                return trip.id != nearest.id
            }
            return true
        }

        // Top 3 remaining scheduled trips for the main dashboard list
        let displayedScheduled = Array(remainingScheduled.prefix(3))

        // History trips (Completed, Rejected, Cancelled) sorted by completion time (latest first)
        let historyTrips = trips.filter {
            $0.status == .completed || $0.status == .rejected || $0.status == .cancelled
        }.sorted { t1, t2 in
            let end1 = t1.endTime ?? t1.startTime
            let end2 = t2.endTime ?? t2.startTime
            return end1 > end2
        }

        // Top 3 history trips for the main dashboard list
        let displayedHistory = Array(historyTrips.prefix(3))

        return NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {

                        HomeHeaderView(
                            showingProfile: $showingProfile,
                            notificationViewModel: notificationViewModel,
                            showingNotifications: $showingNotifications,
                            firstName: user.fName,
                            lastName: user.lName,
                            avatarImageURL: user.avatarImageURL
                        )

                        // --- 1. Active/Post-Trip Section (Highest Priority) ---
                        ZStack {
                            if let pendingPostTrip = localStore.pendingPostTripInspection,
                               let matchingTrip = trips.first(where: { $0.id.uuidString == pendingPostTrip.tripId }) {
                                VStack(alignment: .leading, spacing: 10) {
                                    SectionHeader(title: "Post-Trip Inspection Required")
                                    PostTripInspectionCard(
                                        trip: matchingTrip,
                                        vehicles: vehicles,
                                        onPerformInspection: {
                                            selectedTripForPostInspection = matchingTrip
                                        }
                                    )
                                }
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                            } else if let active = liveTrip {
                                VStack(alignment: .leading, spacing: 10) {
                                    SectionHeader(title: "Active Trip")
                                    ActiveRouteCard(
                                        tripId: active.id.uuidString,
                                        startLocation: active.startLocation,
                                        endLocation: active.endLocation,
                                        distanceCovered: "—",
                                        distanceRemaining: formattedDistance(for: active),
                                        eta: formattedEta(for: active),
                                        remainingTime: "Calculating...",
                                        progress: 0.0,
                                        onCardTap: { showingTripDetailsSheet = true },
                                        onNavigationTap: {
                                            localStore.isNavigationActive = true
                                            activeTripForNavigation = active
                                            showingActiveNavigation = true
                                        },
                                        onFuelTap: { showingFuelSheet = true },
                                        onSOSTap: { showingSOSAlert = true }
                                    )
                                }
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                            } else if let nearest = nearestScheduledTrip {
                                VStack(alignment: .leading, spacing: 10) {
                                    SectionHeader(title: "Upcoming Trip")
                                    UpcomingLiveTripCard(
                                        trip: nearest,
                                        vehicles: vehicles,
                                        isInspected: localStore.inspectedVehicles.contains(nearest.id.uuidString),
                                        activeTripExists: false,
                                        isInspectionEnabled: isInspectionEnabled,
                                        onPerformInspection: {
                                            selectedTripToStart = nearest.id.uuidString
                                            showingInspectionSheet = true
                                        },
                                        onStartTrip: {
                                            Task {
                                                do {
                                                    var updatedTrip = nearest
                                                    updatedTrip.actualStartTime = Date()
                                                    updatedTrip.status = .inProgress
                                                    try await services.tripService.updateTrip(updatedTrip)
                                                    await onRefreshData?()
                                                    await MainActor.run {
                                                        activeTripForNavigation = updatedTrip
                                                        showingActiveNavigation = true
                                                    }
                                                } catch {
                                                    print("Failed to start trip: \(error)")
                                                }
                                            }
                                        }
                                    )
                                }
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                            }
                        }
                        .animation(.spring(response: 0.55, dampingFraction: 0.82), value: liveTrip)
                        .animation(.spring(response: 0.55, dampingFraction: 0.82), value: localStore.inspectedVehicles)
                        .padding(.bottom, 8)

                        // --- Empty State ---
                        if liveTrip == nil && nearestScheduledTrip == nil && trips.isEmpty {
                            VStack(spacing: 16) {
                                Spacer().frame(height: 40)
                                Image(systemName: "truck.box.badge.clock")
                                    .font(.system(size: 60))
                                    .foregroundColor(.secondary.opacity(0.5))
                                Text("No Trips Assigned")
                                    .font(.title2.weight(.bold))
                                    .foregroundColor(.secondary)
                                Text("New trips will appear here once the fleet manager assigns them.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 20)
                        }

                        // --- 3. Scheduled Trips Section ---
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                SectionHeader(title: "Scheduled Trips")
                                Spacer()
                                if remainingScheduled.count > 3 {
                                    NavigationLink(destination: ScheduledTripsListView(trips: remainingScheduled, vehicles: vehicles)) {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(8)
                                            .background(Circle().fill(Color.blue))
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }

                            if displayedScheduled.isEmpty {
                                Text("No other scheduled trips")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 8)
                            } else {
                                VStack(spacing: 16) {
                                    ForEach(displayedScheduled) { trip in
                                        if (trip.status == .pending || trip.status == .scheduled) && Date() < trip.startTime.addingTimeInterval(-3 * 3600) {
                                            PendingRequestCard(
                                                trip: trip,
                                                vehicles: vehicles,
                                                showActions: true,
                                                onCardTap: { selectedScheduledTrip = trip },
                                                onAcceptTap: { Task { await acceptTrip(trip) } },
                                                onRejectTap: { tripToReject = trip }
                                            )
                                        } else {
                                            NavigationLink(destination: TripDetailView(trip: trip).environmentObject(localStore)) {
                                                PendingRequestCard(
                                                    trip: trip,
                                                    vehicles: vehicles,
                                                    showActions: false,
                                                    onCardTap: nil
                                                )
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 8)

                        // --- 4. History Trips Section ---
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                SectionHeader(title: "History Trips")
                                Spacer()
                                if historyTrips.count > 3 {
                                    NavigationLink(destination: HistoryTripsListView(trips: historyTrips, vehicles: vehicles)) {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(8)
                                            .background(Circle().fill(Color.blue))
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }

                            if displayedHistory.isEmpty {
                                Text("No past trips recorded")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 8)
                            } else {
                                VStack(spacing: 16) {
                                    ForEach(displayedHistory) { trip in
                                        NavigationLink(destination: TripDetailView(trip: trip).environmentObject(localStore)) {
                                            PendingRequestCard(
                                                trip: trip,
                                                vehicles: vehicles,
                                                showActions: false,
                                                onCardTap: nil
                                            )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                        }

                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 40)
                }



                if notificationViewModel.showBanner, let banner = notificationViewModel.currentBanner {
                    NotificationBannerView(
                        notification: banner,
                        onTap: {
                            notificationViewModel.dismissCurrentBanner()
                            showingNotifications = true
                        },
                        onDismiss: {
                            notificationViewModel.dismissCurrentBanner()
                        }
                    )
                    .zIndex(99)
                }
            }
            .refreshable {
                await viewModel.fetchDashboardData()
                await onRefreshData?()
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await viewModel.fetchDashboardData()
                await notificationViewModel.loadNotifications()
                notificationViewModel.subscribeToRealtime()
                if let live = trips.first(where: { $0.status == .inProgress }) {
                    activeTripForNavigation = live
                }
            }
            .onChange(of: trips) { _, newTrips in
                if let live = newTrips.first(where: { $0.status == .inProgress }), activeTripForNavigation == nil {
                    activeTripForNavigation = live
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ReloadTrips"))) { _ in
                Task {
                    await viewModel.fetchDashboardData()
                    await onRefreshData?()
                }
            }
            .onDisappear {
                notificationViewModel.unsubscribeRealtime()
            }
            .navigationDestination(isPresented: $showingNotifications) {
                NotificationListView(viewModel: notificationViewModel)
            }
            .navigationDestination(isPresented: $showingProfile) {
                ProfileHubView(
                    services: services,
                    driver: driver,
                    user: user,
                    onLogout: onLogout
                )
            }
            .onChange(of: showingActiveNavigation) { _, newValue in
                if !newValue {
                    Task {
                        await viewModel.fetchDashboardData()
                        await onRefreshData?()
                    }
                }
            }
            .onChange(of: showingInspectionSheet) { _, newValue in
                if !newValue {
                    Task {
                        await viewModel.fetchDashboardData()
                        await onRefreshData?()
                    }
                }
            }
            // MARK: - Action Triggers
            .alert(isPresented: $showingSOSAlert) {
                Alert(
                    title: Text("EMERGENCY SOS"),
                    message: Text("Are you sure you want to trigger an SOS? This will instantly cancel your active trip and alert the fleet manager."),
                    primaryButton: .destructive(Text("Trigger SOS")) {
                        let tripToCancel = trips.first(where: { $0.status == .inProgress }) ?? trips.first(where: { $0.status == .accepted }) ?? trips.first(where: { $0.status == .scheduled })
                        if let trip = tripToCancel {
                            Task {
                                do {
                                    try await services.tripService.updateTripStatus(
                                        id: trip.id,
                                        status: .cancelled,
                                        rejectionReason: "SOS Emergency: Cancelled via emergency SOS alert."
                                    )

                                    let fmUsers = (try? await services.userManagementService.fetchUsers().filter { $0.role == .fleetManager }) ?? []
                                    for fmUser in fmUsers {
                                        let notification = AppNotification(
                                            id: UUID(),
                                            title: "CRITICAL: Driver SOS Emergency",
                                            message: "Driver has triggered emergency SOS alert for Trip from \(trip.startLocation) to \(trip.endLocation).",
                                            type: "sos_emergency",
                                            isRead: false,
                                            referenceId: trip.id,
                                            recipientId: fmUser.id,
                                            createdAt: Date()
                                        )
                                        _ = try? await services.notificationService.createNotification(notification)
                                    }

                                    await viewModel.fetchDashboardData()
                                    await onRefreshData?()
                                } catch {
                                    print("Failed to cancel trip on SOS: \(error)")
                                }
                            }
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
            .sheet(isPresented: $showingFuelSheet) {
                NavigationStack {
                    TripFuelHistoryView(
                        isReadOnly: false,
                        activeTripId: viewModel.activeTripId,
                        vehicleNumber: "",
                        expenseService: services.expenseService,
                        driverId: driver?.id,
                        vehicleId: liveTrip?.vehicleId,
                        vehicleFuelType: nil
                    )
                    .environmentObject(localStore)
                }
            }
            .sheet(isPresented: $showingLogbookSheet) {
                NavigationStack {
                    LogbookView(
                        tripId: liveTrip?.id.uuidString ?? "TRP-8472",
                        startLocation: liveTrip?.startLocation ?? "Yard",
                        endLocation: liveTrip?.endLocation ?? "Destination"
                    )
                }
            }
            .sheet(isPresented: $showingTripSuccess, onDismiss: {
                completedTripForSuccess = nil
                Task {
                    await onRefreshData?()
                }
            }) {
                if let successTrip = completedTripForSuccess {
                    TripCompletionSuccessView(
                        trip: successTrip,
                        distance: successDistance,
                        durationMinutes: successDuration,
                        onDismiss: {
                            showingTripSuccess = false
                        }
                    )
                }
            }
            .sheet(isPresented: $showingInspectionSheet) {
                NavigationStack {
                    InspectionFlowView(
                        services: services,
                        isPresentedModally: true,
                        preselectedTripId: selectedTripToStart,
                        trips: trips,
                        vehicles: vehicles,
                        activeTripId: viewModel.activeTripId
                    )
                }
            }
            .sheet(item: $selectedTripForPostInspection) { tripToInspect in
                EndTripView(
                    trip: tripToInspect,
                    services: services,
                    onComplete: { finalOdometer, notes in
                        localStore.pendingPostTripInspection = nil
                        
                        Task {
                            await onRefreshData?()
                        }
                        
                        // Calculate metrics from real data
                        let tripStart = tripToInspect.actualStartTime ?? tripToInspect.startTime
                        self.successDistance = tripToInspect.distanceKm ?? max(1.2, (Double(finalOdometer) ?? 0) - (tripToInspect.finalOdometer ?? 0))
                        self.successDuration = max(15, Int(Date().timeIntervalSince(tripStart)) / 60)
                        self.completedTripForSuccess = tripToInspect
                        
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            self.showingTripSuccess = true
                        }
                    }
                )
                .environmentObject(localStore)
            }
            .fullScreenCover(isPresented: $showingActiveNavigation) {
                if let activeTrip = activeTripForNavigation {
                    ActiveNavigationDetailView(
                        services: services,
                        user: user,
                        driver: driver,
                        trip: activeTrip,
                        vehicles: vehicles,
                        onBack: { 
                            showingActiveNavigation = false
                            activeTripForNavigation = nil
                            Task {
                                await onRefreshData?()
                            }
                        }
                    )
                    .environmentObject(localStore)
                    .environmentObject(locationService)
                }
            }
            .sheet(isPresented: $showingTripDetailsSheet) {
                ActiveTripDetailView(
                    tripId: viewModel.activeTripId ?? "TRP-8472",
                    startLocation: liveTrip?.startLocation ?? "Bengaluru Yard",
                    endLocation: liveTrip?.endLocation ?? "Pune Distribution Hub",
                    distanceCovered: viewModel.activeTripId == "TRP-083" ? "120 km" : "0 km",
                    distanceRemaining: viewModel.activeTripId == "TRP-083" ? "45 km" : (liveTrip.map { formattedDistance(for: $0) } ?? "0 km"),
                    startTime: "08:32 AM",
                    endTime: liveTrip.map { formattedEta(for: $0) } ?? "14:30 PM",
                    remainingTime: viewModel.activeTripId == "TRP-083" ? "2h 15m" : "Calculating...",
                    progress: viewModel.activeTripId == "TRP-083" ? 0.65 : 0.0
                )
                .environmentObject(localStore)
            }
            .sheet(item: $tripToReject) { trip in
                RejectTripSheet(trip: trip) { reason in
                    Task { await rejectTrip(trip, reason: reason) }
                }
            }
            .sheet(item: $selectedScheduledTrip) { trip in
                NavigationStack {
                    TripDetailView(trip: trip)
                        .environmentObject(localStore)
                }
            }


        }
    }

    private func formattedDistance(for trip: Trip) -> String {
        guard let km = trip.distanceKm, km > 0 else { return "—" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return (formatter.string(from: NSNumber(value: km)) ?? "\(km)") + " km"
    }

    private func formattedEta(for trip: Trip) -> String {
        guard let endTime = trip.endTime else { return "14:30 PM" }
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: endTime)
    }

    private func acceptTrip(_ trip: Trip) async {
        do {
            try await services.tripService.updateTripStatus(id: trip.id, status: .accepted)
            await onRefreshData?()
        } catch {
            print("Failed to accept trip: \(error)")
        }
    }

    private func rejectTrip(_ trip: Trip, reason: String) async {
        do {
            try await services.tripService.updateTripStatus(id: trip.id, status: .rejectionPending, rejectionReason: reason)
            let fmUserId = try? await services.userManagementService.fetchUsers()
                .first(where: { $0.role == .fleetManager })?.id
            let notification = AppNotification(
                id: UUID(),
                title: "Trip Rejected by Driver",
                message: "Driver rejected trip from \(trip.startLocation) to \(trip.endLocation). Reason: \(reason)",
                type: "driver_message",
                isRead: false,
                referenceId: trip.id,
                recipientId: fmUserId,
                createdAt: Date()
            )
            _ = try? await services.notificationService.createNotification(notification)
            await onRefreshData?()
        } catch {
            print("Failed to reject trip: \(error)")
        }
    }
}


struct HomeHeaderView: View {
    @Binding var showingProfile: Bool
    @ObservedObject var notificationViewModel: NotificationViewModel
    @Binding var showingNotifications: Bool
    let firstName: String
    let lastName: String
    let avatarImageURL: URL?

    private var initials: String {
        let f = firstName.first.map { String($0).uppercased() } ?? ""
        let l = lastName.first.map { String($0).uppercased() } ?? ""
        return "\(f)\(l)"
    }

    var body: some View {
        HStack(alignment: .center) {
            Text("Home")
                .font(.system(size: 34, weight: .heavy, design: .default))
                .foregroundColor(.primary)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            NotificationBadge(unreadCount: notificationViewModel.unreadCount) {
                showingNotifications = true
            }
            .padding(.trailing, 8)

            Button(action: {
                HapticManager.shared.triggerImpact(style: .medium)
                showingProfile = true
            }) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color(red: 0.1, green: 0.3, blue: 0.9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                        .shadow(color: Color.blue.opacity(0.2), radius: 4, x: 0, y: 2)

                    if let avatarImageURL {
                        AsyncImage(url: avatarImageURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 36, height: 36)
                                    .clipShape(Circle())
                            default:
                                Text(initials)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                        }
                    } else {
                        Text(initials)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
}
// MARK: - 2. Active Route Card
struct ActiveRouteCard: View {
    let tripId: String
    let startLocation: String
    let endLocation: String
    let distanceCovered: String
    let distanceRemaining: String
    let eta: String
    let remainingTime: String
    let progress: Double
    let onCardTap: () -> Void
    let onNavigationTap: () -> Void
    let onFuelTap: () -> Void
    let onSOSTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 24) {
                // Header with a single Live Trip Badge and ETA
                HStack {
                    HStack(spacing: 6) {
                        Circle().fill(Color.green).frame(width: 8, height: 8).shadow(color: .green, radius: 4)
                        Text("LIVE TRIP")
                            .font(.caption).fontWeight(.heavy).foregroundColor(.white)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Capsule())

                    Spacer()

                    HStack(spacing: 10) {
                        Image(systemName: "clock")
                            .font(.system(size: 16))
                            .foregroundColor(.white)

                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 1, height: 20)

                        HStack(spacing: 4) {
                            Text("ETA")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.7))
                            Text(eta)
                                .font(.system(size: 12, weight: .black))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )
                }

                // Route visualization (Start to End)
                VStack(alignment: .leading, spacing: 0) {
                    Text("START LOCATION")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.leading, 26)
                        .padding(.bottom, 4)
                    
                    HStack(alignment: .top, spacing: 14) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 8, height: 8)
                            .padding(.top, 5)
                            .frame(width: 12)
                        
                        Text(startLocation)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    HStack(alignment: .top, spacing: 14) {
                        Rectangle()
                            .fill(LinearGradient(colors: [.white, .white.opacity(0.25)], startPoint: .top, endPoint: .bottom))
                            .frame(width: 2)
                            .frame(width: 12)
                        
                        Spacer().frame(height: 16)
                    }
                    .frame(height: 24)
                    
                    Text("END LOCATION")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.leading, 26)
                        .padding(.bottom, 4)
                    
                    HStack(alignment: .top, spacing: 14) {
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                            .background(Circle().fill(Color.clear))
                            .frame(width: 8, height: 8)
                            .padding(.top, 5)
                            .frame(width: 12)
                        
                        Text(endLocation)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                // Progress Bar with merged distance covered and left labels below it
                VStack(spacing: 8) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.black.opacity(0.2)).frame(height: 6)
                            Capsule().fill(Color.white).frame(width: geometry.size.width * progress, height: 6)
                                .shadow(color: .white.opacity(0.4), radius: 4, x: 0, y: 0)
                        }
                    }
                    .frame(height: 6)

                    HStack {
                        Text("\(distanceCovered) Covered")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.85))

                        Spacer()

                        Text("\(distanceRemaining) Left")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
            }

            // Action Buttons
            VStack(spacing: 12) {
                Button(action: onNavigationTap) {
                    HStack {
                        Image(systemName: "location.north.line.fill")
                        Text(UserDefaults.standard.bool(forKey: "trip_\(tripId)_paused") ? "Continue" : "Open Navigation")
                    }
                    .font(.headline).fontWeight(.bold).frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color(red: 0.12, green: 0.26, blue: 0.55))
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                .buttonStyle(PlainButtonStyle())

                HStack(spacing: 12) {
                    Button(action: onFuelTap) {
                        HStack {
                            Image(systemName: "fuelpump.fill")
                                .foregroundColor(.orange)
                            Text("Log Fuel")
                                .font(.headline).fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(Color(red: 0.12, green: 0.26, blue: 0.55))
                        .cornerRadius(16)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: onSOSTap) {
                        HStack {
                            Image(systemName: "light.beacon.max.fill")
                                .foregroundColor(.red)
                            Text("SOS")
                                .font(.headline).fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(Color(red: 0.12, green: 0.26, blue: 0.55))
                        .cornerRadius(16)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(32)
        .background(
            LinearGradient(
                colors: [Color(red: 0.0, green: 0.5, blue: 1.0), Color(red: 0.05, green: 0.3, blue: 0.95)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(24)
        .shadow(color: Color.blue.opacity(0.25), radius: 20, x: 0, y: 12)
        .accessibilityLabel("Active Route from \(startLocation) to \(endLocation). Covered \(distanceCovered), remaining distance \(distanceRemaining), ETA \(eta).")
    }
}

// MARK: - 3. Urgent Task Card
struct UrgentTaskCard: View {
    let title: String
    let type: String
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(Color.red.opacity(0.15)).frame(width: 50, height: 50)
                Image(systemName: "exclamationmark.shield.fill").foregroundColor(.red).font(.title2)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(type).font(.system(size: 11, weight: .black)).foregroundColor(.red)
                Text(title).font(.headline).fontWeight(.bold).foregroundColor(.primary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.gray.opacity(0.5))
                .accessibilityHidden(true)
        }
        .padding(20).background(Color(UIColor.systemBackground)).cornerRadius(20).shadow(color: Color.red.opacity(0.1), radius: 15, x: 0, y: 5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(type): \(title)")
        .accessibilityHint("Tapping this will open the pre-trip inspection workflow.")
    }
}

// MARK: - 4. Compliance & Vitals Widget
struct ComplianceWidget: View {
    let title: String
    let value: String
    let subtitle: String
    let progress: Double
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.subheadline).fontWeight(.bold).foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.system(size: 24, weight: .heavy, design: .rounded)).foregroundColor(.primary)
                Text(subtitle).font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(UIColor.systemGroupedBackground)).frame(height: 6)
                    Capsule().fill(color).frame(width: geometry.size.width * progress, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Color(UIColor.systemBackground))
        .cornerRadius(20).shadow(color: Color.black.opacity(0.03), radius: 15, x: 0, y: 5)
    }
}

// MARK: - 5. Quick Action Row (UPDATED FOR INTERACTIVITY)
struct QuickActionRow: View {
    let onLogbookTap: () -> Void
    let onFuelTap: () -> Void
    let onSOSTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ActionTile(icon: "book.pages.fill", title: "Logbook", color: .purple, action: onLogbookTap)
            ActionTile(icon: "fuelpump.fill", title: "Fuel", color: .orange, action: onFuelTap)
            ActionTile(icon: "light.beacon.max.fill", title: "SOS", color: .red, action: onSOSTap)
        }
    }
}

struct ActionTile: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(title)
    }
}

struct PendingRequestCard: View {
    let trip: Trip
    let vehicles: [Vehicle]
    var showActions: Bool = true
    var onCardTap: (() -> Void)? = nil
    var onAcceptTap: (() -> Void)? = nil
    var onRejectTap: (() -> Void)? = nil

    private var vehicleNumber: String {
        vehicles.first(where: { $0.id == trip.vehicleId })?.licencePlate ?? ""
    }

    private var displayDistance: String {
        guard let km = trip.distanceKm, km > 0 else { return "—" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return (formatter.string(from: NSNumber(value: km)) ?? "\(km)") + " km"
    }

    private var displayEta: String {
        guard let endTime = trip.endTime else { return "14:30 PM" }
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: endTime)
    }

    private var formattedStartTime: String {
        let f = DateFormatter()
        f.dateFormat = "d MMM, h:mm a"
        return f.string(from: trip.startTime)
    }

    private var formattedEndTime: String {
        guard let endTime = trip.endTime else {
            return "N/A"
        }
        let f = DateFormatter()
        f.dateFormat = "d MMM, h:mm a"
        return f.string(from: endTime)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                    // Header: ID and Vehicle
                    HStack {
                        Text(trip.id.shortIdentifier)
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(.blue)
                        Spacer()

                        // Vehicle Capsule
                        HStack(spacing: 6) {
                            Image(systemName: "truck.box.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.blue)
                            Text(vehicleNumber)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.08))
                        .clipShape(Capsule())
                    }

                    // Route Info (Start to End Locations)
                    VStack(alignment: .leading, spacing: 0) {
                        // Origin header
                        Text("ORIGIN")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.leading, 24)
                            .padding(.bottom, 4)
                        
                        // Origin Address Row
                        HStack(alignment: .top, spacing: 12) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                                .padding(.top, 5)
                                .frame(width: 12)
                            
                            Text(trip.startLocation)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                        }
                        
                        // Connector line & distance
                        HStack(alignment: .top, spacing: 12) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 2)
                                .frame(width: 12)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "road.lanes")
                                    .font(.system(size: 9))
                                    .foregroundColor(.purple)
                                Text(displayDistance)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.purple)
                            }
                            .padding(.vertical, 4)
                        }
                        .frame(height: 24)
                        
                        // Destination header
                        Text("DESTINATION")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.leading, 24)
                            .padding(.bottom, 4)
                        
                        // Destination Address Row
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "flag.fill")
                                .foregroundColor(.red)
                                .font(.system(size: 8))
                                .padding(.top, 5)
                                .frame(width: 12)
                            
                            Text(trip.endLocation)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                        }
                    }

                    // Schedule (Start/End Date & Time)
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("START DATE & TIME")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                            Text(formattedStartTime)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("END DATE & TIME")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                            Text(formattedEndTime)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.vertical, 4)

                }
                .onTapGestureIf(enabled: !showActions && onCardTap != nil) {
                    onCardTap?()
                }

            if showActions {
                Divider()

                // Accept & Reject Buttons
                HStack(spacing: 12) {
                    Button(action: { onRejectTap?() }) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text("Reject")
                        }
                        .font(.subheadline).fontWeight(.bold)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.08))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: { onAcceptTap?() }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Accept")
                        }
                        .font(.subheadline).fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .cornerRadius(12)
                        .shadow(color: Color.green.opacity(0.15), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.03), radius: 15, x: 0, y: 5)
    }
}
struct ManifestRow: View {
    let id: String
    let destination: String
    let status: String
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(destination).font(.subheadline).fontWeight(.bold)
                Text("Trip: \(id)").font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Text(status).font(.system(size: 11, weight: .bold)).foregroundColor(.secondary).padding(.horizontal, 10).padding(.vertical, 6).background(Color(UIColor.systemGroupedBackground)).clipShape(Capsule())
        }
        .padding(20)
    }
}

struct SectionHeader: View {
    let title: String
    var body: some View { HStack { Text(title).font(.title3).fontWeight(.bold).foregroundColor(.primary); Spacer() } }
}


// MARK: - FUEL LOG

struct FuelLogView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var localStore: LocalDataStore

    @State private var fuelAmount: String = ""
    @State private var selectedType: String = "Diesel"
    @State private var notes: String = ""

    let fuelTypes = ["Diesel", "Petrol", "CNG"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Fuel Details").font(.headline)
                        TextField("Amount (Liters)", text: $fuelAmount)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                        Picker("Type", selection: $selectedType) {
                            ForEach(fuelTypes, id: \.self) { type in
                                Text(type).tag(type)
                            }
                        }
                        TextField("Notes (optional)", text: $notes)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(.vertical, 8)
                }.padding(.horizontal)

                Button("Save Fuel Entry") {
                    let fuelType: FuelRecord.FuelType = selectedType == "Petrol" ? .petrol : selectedType == "CNG" ? .cng : .diesel
                    localStore.submitFuelRequest(vehicleId: "", fuelType: fuelType, amount: Double(fuelAmount) ?? 0, currentLevel: 0)
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .disabled(fuelAmount.isEmpty)
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top)
            .navigationTitle("Log Fuel")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

struct LogbookView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var localStore: LocalDataStore

    let tripId: String
    let startLocation: String
    let endLocation: String

    init(tripId: String = "TRP-8472", startLocation: String = "Bengaluru Yard", endLocation: String = "Pune Distribution Hub") {
        self.tripId = tripId
        self.startLocation = startLocation
        self.endLocation = endLocation
    }

    private var milestones: [JourneyMilestone] {
        [
            JourneyMilestone(time: "07:30", title: "Departed \(startLocation)", detail: "Trip \(tripId) started", status: .completed, icon: "flag.fill"),
            JourneyMilestone(time: "--:--", title: "Arrive \(endLocation)", detail: "Trip destination", status: .upcoming, icon: "flag.checkered")
        ]
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                logbookHeader
                complianceStrip
                dutySummary
                journeyTimeline
                driverNotes
            }
            .padding()
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Journey Logbook")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            // pull-to-refresh handled by parent
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Close") {
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
    }

    // MARK: - Subviews

    // Removed inspectionActionBlock entirely

    private var logbookHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(tripId)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                    Text("\(startLocation) to \(endLocation)")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.82))
                }
                Spacer()
                VStack(spacing: 4) {
                    Image(systemName: "book.pages.fill")
                        .font(.title2)
                    Text("LIVE")
                        .font(.system(size: 10, weight: .black))
                }
                .foregroundColor(.white)
                .padding(10)
                .background(Color.white.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            HStack(spacing: 10) {
                LogbookPill(icon: "car.fill", text: "KA-01-HC-1234")
                LogbookPill(icon: "clock.fill", text: "Start 08:32")
                LogbookPill(icon: "flag.fill", text: "ETA 14:30")
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Journey Progress")
                        .font(.caption)
                        .fontWeight(.bold)
                    Spacer()
                    Text("58%")
                        .font(.caption)
                        .fontWeight(.heavy)
                }
                ProgressView(value: 0.58)
                    .tint(.white)
                    .scaleEffect(x: 1, y: 1.8, anchor: .center)
            }
        }
        .padding(20)
        .foregroundColor(.white)
        .background(LinearGradient(colors: [Color(red: 0.20, green: 0.19, blue: 0.42), Color(red: 0.08, green: 0.36, blue: 0.50)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .cornerRadius(20)
    }

    private var complianceStrip: some View {
        HStack(spacing: 12) {
            LogbookMetric(title: "Drive Time", value: "4h 12m", caption: "48m to break", color: .blue, icon: "timer")
            LogbookMetric(title: "Duty Status", value: "Driving", caption: "On route", color: .green, icon: "steeringwheel")
            LogbookMetric(title: "Shift Left", value: "5h 18m", caption: "Legal window", color: .orange, icon: "hourglass")
        }
    }

    private var dutySummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Current Duty State")
                .font(.headline)
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.14))
                        .frame(width: 46, height: 46)
                    Image(systemName: "location.north.line.fill")
                        .foregroundColor(.green)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Driving to next stop")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Text("Break should begin before 10:45 to keep this trip compliant.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        .padding(16)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
    }

    private var journeyTimeline: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Timed Journey Map")
                    .font(.headline)
                Spacer()
                Text("Auto-sync")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }

            VStack(spacing: 0) {
                ForEach(Array(milestones.enumerated()), id: \.element.id) { index, milestone in
                    TimelineRow(milestone: milestone, isLast: index == milestones.count - 1)
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
    }

    private var driverNotes: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "exclamationmark.shield.fill")
                    .foregroundColor(.orange)
                Text("Driver Focus")
                    .font(.headline)
            }
            Text("Next required action is the break window. The logbook keeps the compliance clock, route status, and closeout tasks visible so the driver does not need to hunt across screens while working.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.orange.opacity(0.10))
        .cornerRadius(16)
    }
}
struct JourneyMilestone: Identifiable {
    let id = UUID()
    let time: String
    let title: String
    let detail: String
    let status: JourneyMilestoneStatus
    let icon: String
}

enum JourneyMilestoneStatus {
    case completed
    case current
    case upcoming

    var color: Color {
        switch self {
        case .completed: return .green
        case .current: return .blue
        case .upcoming: return .gray
        }
    }

    var label: String {
        switch self {
        case .completed: return "Done"
        case .current: return "Now"
        case .upcoming: return "Next"
        }
    }
}

struct LogbookPill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
            Text(text)
                .lineLimit(1)
        }
        .font(.system(size: 11, weight: .bold))
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.16))
        .clipShape(Capsule())
    }
}

struct LogbookMetric: View {
    let title: String
    let value: String
    let caption: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.8)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.primary)
                Text(caption)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(14)
    }
}

struct TimelineRow: View {
    let milestone: JourneyMilestone
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(milestone.status.color.opacity(0.16))
                        .frame(width: 36, height: 36)
                    Image(systemName: milestone.icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(milestone.status.color)
                }
                if !isLast {
                    Rectangle()
                        .fill(milestone.status.color.opacity(0.25))
                        .frame(width: 2, height: 44)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(milestone.time)
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundColor(milestone.status.color)
                    Text(milestone.title)
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Spacer()
                    Text(milestone.status.label)
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(milestone.status.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(milestone.status.color.opacity(0.12))
                        .clipShape(Capsule())
                }
                Text(milestone.detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, isLast ? 0 : 16)
        }
    }
}

struct ActiveTripDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var localStore: LocalDataStore

    let tripId: String
    let startLocation: String
    let endLocation: String
    let distanceCovered: String
    let distanceRemaining: String
    let startTime: String
    let endTime: String
    let remainingTime: String
    let progress: Double

    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        // Immersive Header Card
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("CURRENT TRIP ASSIGNMENT")
                                        .font(.system(size: 10, weight: .black))
                                        .foregroundColor(.white.opacity(0.7))
                                    Text(tripId)
                                        .font(.system(size: 34, weight: .black, design: .rounded))
                                        .foregroundColor(.white)
                                }
                                Spacer()
                                HStack(spacing: 6) {
                                    Circle().fill(Color.green).frame(width: 8, height: 8).shadow(color: .green, radius: 4)
                                    Text("LIVE TRIP")
                                        .font(.system(size: 10, weight: .black))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Capsule())
                            }
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color(red: 0.1, green: 0.3, blue: 0.9)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(24)
                        .shadow(color: Color.blue.opacity(0.2), radius: 15, x: 0, y: 8)

                        // 1. Route & Locations Card (Structured vertical timeline layout)
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "map.fill")
                                    .foregroundColor(.green)
                                Text("Route & Locations")
                                    .font(.headline)
                                    .fontWeight(.bold)
                            }

                            Divider()

                            HStack(alignment: .top, spacing: 16) {
                                // Vertical timeline node line
                                VStack(spacing: 0) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 10, height: 10)

                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 2, height: 44)

                                    Image(systemName: "flag.fill")
                                        .foregroundColor(.red)
                                        .font(.system(size: 10))
                                }
                                .padding(.top, 4)

                                VStack(alignment: .leading, spacing: 18) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("START LOCATION")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.secondary)
                                        Text(startLocation)
                                            .font(.body)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("END LOCATION")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.secondary)
                                        Text(endLocation)
                                            .font(.body)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 4)


                        // 2. Time / Schedule Vitals Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(.purple)
                                Text("Trip Vitals")
                                    .font(.headline)
                                    .fontWeight(.bold)
                            }

                            Divider()

                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("DEPARTED")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.secondary)
                                    Text(startTime)
                                        .font(.headline)
                                        .fontWeight(.black)
                                        .foregroundColor(.primary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                VStack(alignment: .center, spacing: 4) {
                                    Text("ETA")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.secondary)
                                    Text(endTime)
                                        .font(.headline)
                                        .fontWeight(.black)
                                        .foregroundColor(.primary)
                                }
                                .frame(maxWidth: .infinity, alignment: .center)

                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("TIME LEFT")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.secondary)
                                    Text(remainingTime)
                                        .font(.headline)
                                        .fontWeight(.black)
                                        .foregroundColor(.orange)
                                }
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                        .padding(20)
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 4)

                        // 3. Distance and Progress Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "road.lanes")
                                    .foregroundColor(.blue)
                                Text("Distance & Progress")
                                    .font(.headline)
                                    .fontWeight(.bold)
                            }

                            Divider()

                            VStack(spacing: 12) {
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color(UIColor.systemGroupedBackground)).frame(height: 8)
                                        Capsule().fill(Color.blue).frame(width: geometry.size.width * progress, height: 8)
                                            .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 0)
                                    }
                                }
                                .frame(height: 8)

                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("COVERED")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.secondary)
                                        Text(distanceCovered)
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("REMAINING")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.secondary)
                                        Text(distanceRemaining)
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 4)

                        // 4. Vehicle Details Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "truck.box.fill")
                                    .foregroundColor(.green)
                                Text("Vehicle Information")
                                    .font(.headline)
                                    .fontWeight(.bold)
                            }

                            Divider()

                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("ASSIGNED TRUCK")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.secondary)
                                    Text("KA-01-HC-1234")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                }

                                Spacer()

                            }
                        }
                        .padding(20)
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 4)

                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Active Trip Information")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

struct UpcomingLiveTripCard: View {
    let trip: Trip
    let vehicles: [Vehicle]
    let isInspected: Bool
    let activeTripExists: Bool
    let isInspectionEnabled: Bool
    let onPerformInspection: () -> Void
    let onStartTrip: () -> Void

    private var vehicleNumber: String {
        vehicles.first(where: { $0.id == trip.vehicleId })?.licencePlate ?? ""
    }

    private var displayDistance: String {
        guard let km = trip.distanceKm, km > 0 else { return "—" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return (formatter.string(from: NSNumber(value: km)) ?? "\(km)") + " km"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(Color.orange).frame(width: 8, height: 8)
                    Text("UPCOMING TRIP")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color.white.opacity(0.12))
                .clipShape(Capsule())

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(trip.startTime, style: .date)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                    Text(trip.startTime, style: .time)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                    Text(trip.startTime, style: .timer)
                        .font(.caption2)
                        .foregroundColor(.orange.opacity(0.9))
                }
            }

            // Route Detail
            VStack(alignment: .leading, spacing: 0) {
                // Origin header
                Text("ORIGIN")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(red: 0.65, green: 0.75, blue: 0.9))
                    .padding(.leading, 28)
                    .padding(.bottom, 4)
                
                HStack(alignment: .top, spacing: 14) {
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: 10, height: 10)
                        .padding(.top, 5)
                        .frame(width: 14)
                    
                    Text(trip.startLocation)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                
                HStack(alignment: .top, spacing: 14) {
                    Rectangle()
                        .fill(Color.white.opacity(0.4))
                        .frame(width: 2)
                        .frame(width: 14)
                    
                    Spacer().frame(height: 12)
                }
                .frame(height: 20)
                
                // Destination header
                Text("DESTINATION")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(red: 0.65, green: 0.75, blue: 0.9))
                    .padding(.leading, 28)
                    .padding(.bottom, 4)
                
                HStack(alignment: .top, spacing: 14) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 10, height: 10)
                        .padding(.top, 5)
                        .frame(width: 14)
                    
                    Text(trip.endLocation)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
            }
                Divider()
                    .background(Color.white.opacity(0.15))
                    .padding(.vertical, 4)

                // Vehicle Details
                HStack {
                    Label(vehicleNumber, systemImage: "truck.box.fill")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(red: 0.65, green: 0.75, blue: 0.9))

                    Spacer()

                    Label(displayDistance, systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(red: 0.65, green: 0.75, blue: 0.9))
                }

            // Interactive button with gating check
            if activeTripExists {
                VStack(spacing: 8) {
                    HStack {
                        Spacer()
                        Image(systemName: "lock.fill")
                        Text("Pre-Trip Inspection Locked")
                            .fontWeight(.bold)
                        Spacer()
                    }
                    .padding(.vertical, 16)
                    .background(Color.white.opacity(0.15))
                    .foregroundColor(.white.opacity(0.6))
                    .cornerRadius(14)

                    Text("Complete your active trip to unlock this inspection.")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } else if !isInspected {
                if isInspectionEnabled {
                    Button(action: {
                        HapticManager.shared.triggerImpact(style: .medium)
                        onPerformInspection()
                    }) {
                        HStack {
                            Spacer()
                            Text("Perform Pre-Trip Inspection")
                                .font(.headline)
                                .fontWeight(.bold)
                            Spacer()
                        }
                        .padding(.vertical, 16)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .shadow(color: Color.orange.opacity(0.35), radius: 8, x: 0, y: 4)
                    }
                } else {
                    VStack(spacing: 8) {
                        HStack {
                            Spacer()
                            Image(systemName: "lock.fill")
                            Text("Pre-Trip Inspection Locked")
                                .fontWeight(.bold)
                            Spacer()
                        }
                        .padding(.vertical, 16)
                        .background(Color.white.opacity(0.15))
                        .foregroundColor(.white.opacity(0.6))
                        .cornerRadius(14)

                        Text("Available 3 hours before scheduled departure.")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            } else {
                Button(action: {
                    HapticManager.shared.triggerImpact(style: .medium)
                    onStartTrip()
                }) {
                    HStack {
                        Spacer()
                        Image(systemName: "play.fill")
                        Text("Start Trip")
                            .font(.headline)
                            .fontWeight(.bold)
                        Spacer()
                    }
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.blue, Color(red: 0.12, green: 0.32, blue: 0.82)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    .shadow(color: Color.blue.opacity(0.35), radius: 8, x: 0, y: 4)
                }
            }
        }
        .padding(24)
        .background(Color(red: 0.11, green: 0.18, blue: 0.35))
        .cornerRadius(28)
        .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
    }
}

struct ScheduledTripsListView: View {
    let trips: [Trip]
    let vehicles: [Vehicle]
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var localStore: LocalDataStore

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    ForEach(trips) { trip in
                        NavigationLink(destination: TripDetailView(trip: trip).environmentObject(localStore)) {
                            PendingRequestCard(
                                trip: trip,
                                vehicles: vehicles,
                                showActions: false,
                                onCardTap: nil
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Scheduled Trips")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

struct HistoryTripsListView: View {
    let trips: [Trip]
    let vehicles: [Vehicle]
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var localStore: LocalDataStore

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    ForEach(trips) { trip in
                        NavigationLink(destination: TripDetailView(trip: trip).environmentObject(localStore)) {
                            PendingRequestCard(
                                trip: trip,
                                vehicles: vehicles,
                                showActions: false,
                                onCardTap: nil
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("History Trips")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

extension View {
    @ViewBuilder
    func onTapGestureIf(enabled: Bool, action: @escaping () -> Void) -> some View {
        if enabled {
            self.contentShape(Rectangle()).onTapGesture(perform: action)
        } else {
            self
        }
    }
}

struct PostTripInspectionCard: View {
    @EnvironmentObject var localStore: LocalDataStore
    let trip: Trip
    let vehicles: [Vehicle]
    let onPerformInspection: () -> Void

    @State private var now = Date()

    private var deadline: Date? {
        localStore.pendingPostTripInspection?.deadline
    }

    private var timeRemaining: TimeInterval {
        guard let deadline else { return 0 }
        return deadline.timeIntervalSince(now)
    }

    private var isOverdue: Bool {
        timeRemaining <= 0
    }

    private var countdownText: String {
        guard let deadline else { return "" }
        if isOverdue { return "Overdue" }
        let remaining = Int(timeRemaining)
        let hours = remaining / 3600
        let minutes = (remaining % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m remaining"
        }
        return "\(minutes)m remaining"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(isOverdue ? "OVERDUE POST-TRIP INSPECTION" : "PENDING POST-TRIP INSPECTION")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(isOverdue ? .red : .orange)
                            .tracking(1.0)

                        Text("Complete within 2 hours of trip completion")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    let plate = vehicles.first(where: { $0.id == trip.vehicleId })?.licencePlate ?? "Unknown"
                    Text("Vehicle: \(plate)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                Spacer()
                Image(systemName: isOverdue ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(isOverdue ? .red : .orange)
                    .font(.title2)
            }

            HStack(spacing: 8) {
                Image(systemName: "number")
                    .foregroundColor(.secondary)
                Text("Trip ID: \(trip.id.shortIdentifier)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if let deadline {
                HStack(spacing: 6) {
                    Image(systemName: isOverdue ? "clock.badge.exclamationmark" : "clock")
                        .foregroundColor(isOverdue ? .red : .orange)
                    Text(countdownText)
                        .font(.caption.weight(.bold))
                        .foregroundColor(isOverdue ? .red : .orange)
                    Text("- Due \(deadline.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Button(action: onPerformInspection) {
                HStack {
                    Text("Perform Post-Trip Inspection")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.subheadline.bold())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .foregroundColor(.white)
                .background(isOverdue ? Color.red : Color.orange)
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 10, y: 5)
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { newNow in
            now = newNow
        }
    }
}

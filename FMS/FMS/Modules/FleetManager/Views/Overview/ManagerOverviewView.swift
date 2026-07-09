import SwiftUI

struct ManagerOverviewView: View {
    @ObservedObject var usersViewModel: UserManagementViewModel
    @ObservedObject var vehiclesViewModel: VehicleViewModel
    @ObservedObject var tripsViewModel: TripManagementViewModel
    @ObservedObject var maintenanceViewModel: MaintenanceViewModel
    @ObservedObject var notificationViewModel: NotificationViewModel
    @Binding var showingNotifications: Bool

    var refresh: () async -> Void
    var currentUserId: UUID?
    var onProfile: (() -> Void)?
    var onShowReportsHub: (() -> Void)?
    @State private var selectedActiveTripID: UUID?
    @State private var showInlineTitle = false
    @State private var scrollOffset: CGFloat = 0

    private var titleOpacity: Double {
        let threshold: CGFloat = 10.0
        let progress = min(max(scrollOffset / threshold, 0.0), 1.0)
        return 1.0 - Double(progress)
    }

    private var titleBlur: CGFloat {
        let threshold: CGFloat = 10.0
        let progress = min(max(scrollOffset / threshold, 0.0), 1.0)
        return progress * 6.0
    }

    private var activeTrips: [Trip] {
        tripsViewModel.trips
            .filter { $0.status == .accepted || $0.status == .inProgress }
            .sorted { $0.startTime > $1.startTime }
    }

    private var pendingTrips: [Trip] {
        tripsViewModel.trips
            .filter { $0.status == .pending }
            .sorted { $0.startTime < $1.startTime }
    }

    private var completedTrips: [Trip] {
        tripsViewModel.trips
            .filter { $0.status == .completed }
            .sorted { ($0.endTime ?? $0.startTime) > ($1.endTime ?? $1.startTime) }
    }

    private var busyDriverIDs: Set<UUID> {
        Set(activeTrips.compactMap(\.driverId))
    }

    private var availableDrivers: [Driver] {
        usersViewModel.drivers.filter { $0.status == .available }
    }

    private var enrouteDrivers: [Driver] {
        usersViewModel.drivers.filter { $0.status == .onTrip || $0.status == .scheduled }
    }

    private var offDutyDrivers: [Driver] {
        usersViewModel.drivers.filter { $0.status != .available && $0.status != .onTrip && $0.status != .scheduled }
    }

    private var availableVehicles: [Vehicle] {
        vehiclesViewModel.vehicles.filter { $0.status == .available }
    }

    private var enrouteVehicles: [Vehicle] {
        vehiclesViewModel.vehicles.filter { $0.status == .assigned }
    }

    private var maintenanceVehicles: [Vehicle] {
        vehiclesViewModel.maintenanceVehicles
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    headerBar
                    activeTripsHeaderCard
                    fleetStatusSection
                    ReportsNavRow(action: onShowReportsHub)
                }
                .padding()
                .padding(.bottom, 10)
            }
            .padding(.top, -44)
            .fleetScreenBackground()
            .navigationTitle(showInlineTitle ? "Dashboard" : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        NotificationBadge(unreadCount: notificationViewModel.unreadCount) {
                            showingNotifications = true
                        }
                        Button(action: { onProfile?() }) {
                            profileIcon
                        }
                        .accessibilityLabel("Account")
                    }
                }
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y
            } action: { oldValue, newValue in
                scrollOffset = newValue
                showInlineTitle = newValue > 10
            }
            .refreshable {
                await refresh()
            }
            .task {
                await refresh()
            }
        }
    }

    private var headerBar: some View {
        HStack(alignment: .center) {
            ScreenHeader(title: "Dashboard")
                .blur(radius: titleBlur)
                .opacity(titleOpacity)
            Spacer()
        }
        .padding(.top, 26)
    }

    @ViewBuilder
    private var profileIcon: some View {
        if let user = currentUserId.flatMap({ usersViewModel.user(for: $0) }),
           let imageURL = user.avatarImageURL {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                default:
                    fallbackProfileIcon
                }
            }
        } else {
            fallbackProfileIcon
        }
    }

    private var fallbackProfileIcon: some View {
        Image("Profile")
            .resizable()
            .scaledToFill()
            .frame(width: 28, height: 28)
            .clipShape(Circle())
            .frame(width: 32, height: 32)
    }

    private var activeTripsHeaderCard: some View {
        Group {
            if activeTrips.isEmpty {
                FleetStatusOverviewGradientCard()
            } else {
                VStack(spacing: 10) {
                    TabView(selection: activeTripSelection) {
                        ForEach(activeTrips) { trip in
                            ActiveTripGradientCard(
                                trip: trip,
                                tripsViewModel: tripsViewModel,
                                vehiclesViewModel: vehiclesViewModel,
                                usersViewModel: usersViewModel
                            )
                            .tag(Optional(trip.id))
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: 276)

                    ActiveTripPageIndicator(
                        activeTripIDs: activeTrips.map(\.id),
                        selectedTripID: activeTripSelection.wrappedValue
                    )
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var activeTripSelection: Binding<UUID?> {
        Binding {
            if let selectedActiveTripID,
               activeTrips.contains(where: { $0.id == selectedActiveTripID }) {
                return selectedActiveTripID
            }
            return activeTrips.first?.id
        } set: { newValue in
            selectedActiveTripID = newValue
        }
    }

    private var fleetStatusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            DashboardSectionTitle("Fleet Status")
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    NavigationLink {
                        DashboardDriverStatusListView(
                            usersViewModel: usersViewModel,
                            tripsViewModel: tripsViewModel,
                            maintenanceViewModel: maintenanceViewModel,
                            activeDrivers: enrouteDrivers,
                            availableDrivers: availableDrivers,
                            offDutyDrivers: offDutyDrivers
                        )
                    } label: {
                        FleetStatusCard(
                            title: "Drivers",
                            systemImage: "person.2.fill",
                            titleTint: FleetPalette.accent,
                            metrics: [
                                ("location.north.fill", "\(enrouteDrivers.count)", "ON TRIP", FleetPalette.success),
                                ("person.fill", "\(availableDrivers.count)", "AVAILABLE", FleetPalette.accent),
                                ("moon.fill", "\(offDutyDrivers.count)", "OFF DUTY", FleetPalette.neutral)
                            ]
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        DashboardVehicleStatusListView(
                            usersViewModel: usersViewModel,
                            vehiclesViewModel: vehiclesViewModel,
                            maintenanceViewModel: maintenanceViewModel,
                            onTripVehicles: enrouteVehicles,
                            availableVehicles: availableVehicles,
                            maintenanceVehicles: maintenanceVehicles
                        )
                    } label: {
                        FleetStatusCard(
                            title: "Vehicles",
                            systemImage: "car.fill",
                            titleTint: FleetPalette.accent,
                            metrics: [
                                ("truck.box.fill", "\(enrouteVehicles.count)", "ON TRIP", FleetPalette.success),
                                ("truck.box.fill", "\(availableVehicles.count)", "AVAILABLE", FleetPalette.accent),
                                ("wrench.and.screwdriver.fill", "\(maintenanceVehicles.count)", "MAINTENANCE", FleetPalette.warning)
                            ]
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        DashboardMaintenanceStatusListView(
                            usersViewModel: usersViewModel,
                            vehiclesViewModel: vehiclesViewModel,
                            maintenanceViewModel: maintenanceViewModel,
                            openTasks: maintenanceViewModel.openTasks,
                            inProgressTasks: maintenanceViewModel.tasks.filter { $0.status == .inProgress },
                            completedTasks: maintenanceViewModel.tasks.filter { $0.status == .completed || $0.status == .verified || $0.status == .closed }
                        )
                    } label: {
                        FleetStatusCard(
                            title: "Maintenance",
                            systemImage: "wrench.and.screwdriver.fill",
                            titleTint: FleetPalette.warning,
                            metrics: [
                                ("exclamationmark.circle.fill", "\(maintenanceViewModel.openTasks.count)", "OPEN", FleetPalette.warning),
                                ("clock.fill", "\(maintenanceViewModel.tasks.filter { $0.status == .inProgress }.count)", "IN PROGRESS", FleetPalette.accent),
                                ("checkmark.circle.fill", "\(maintenanceViewModel.tasks.filter { $0.status == .completed || $0.status == .verified || $0.status == .closed }.count)", "COMPLETED", FleetPalette.success)
                            ]
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 8)
            }
        }
    }
}

private struct ActiveTripPageIndicator: View {
    let activeTripIDs: [UUID]
    let selectedTripID: UUID?

    var body: some View {
        HStack(spacing: 8) {
            ForEach(activeTripIDs, id: \.self) { tripID in
                Circle()
                    .fill(tripID == selectedTripID ? FleetPalette.accent : FleetPalette.secondary)
                    .frame(width: 8, height: 8)
                    .opacity(tripID == selectedTripID ? 1 : 0.55)
            }
        }
        .padding(.top, 2)
        .accessibilityHidden(true)
    }
}

struct FleetStatusOverviewGradientCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.white.opacity(0.8))
                        .frame(width: 8, height: 8)
                    Text("FLEET OVERVIEW")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.15))
                .clipShape(Capsule())

                Spacer()

                Image(systemName: "shippingbox.fill")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("No Active Trips")
                    .font(.title3.weight(.bold))
                    .foregroundColor(.white)
                Text("All fleet vehicles are currently available, off duty, or scheduled for service.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(20)
        .frame(height: 180)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color(hex: 0x113B70), Color(hex: 0x0B2347)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.gray, lineWidth: 1)
        )
    }
}

struct ActiveTripGradientCard: View {
    @Environment(\.colorScheme) var colorScheme
    let trip: Trip
    @ObservedObject var tripsViewModel: TripManagementViewModel
    @ObservedObject var vehiclesViewModel: VehicleViewModel
    @ObservedObject var usersViewModel: UserManagementViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: 0x00E676))
                        .frame(width: 8, height: 8)
                        .shadow(color: Color(hex: 0x00E676), radius: 4)
                    Text("LIVE TRIP")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.15))
                .clipShape(Capsule())

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                    Text("ETA \(formattedTime(trip.endTime ?? trip.startTime.addingTimeInterval(8 * 3600)))")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.15))
                .clipShape(Capsule())
            }

            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 0) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                    Rectangle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 2, height: 26)
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: 8, height: 8)
                }
                .padding(.top, 4)

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("START LOCATION")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                        Text(trip.startLocation)
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("END LOCATION")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                        Text(trip.endLocation)
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                }
            }

            VStack(spacing: 6) {
                let progress = getTripProgress(for: trip)
                let dist = getTripDistances(for: trip)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.black.opacity(0.15))
                            .frame(height: 6)
                        Capsule()
                            .fill(Color.white)
                            .frame(width: geometry.size.width * progress, height: 6)
                            .shadow(color: .white.opacity(0.4), radius: 4)
                    }
                }
                .frame(height: 6)

                HStack {
                    Text("\(dist.covered) km Covered")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.white.opacity(0.85))
                    Spacer()
                    Text("\(dist.left) km Left")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.white.opacity(0.85))
                }
            }

            NavigationLink {
                ManagerTripDetailView(
                    trip: trip,
                    viewModel: tripsViewModel,
                    vehiclesViewModel: vehiclesViewModel,
                    usersViewModel: usersViewModel
                )
            } label: {
                HStack {
                    Image(systemName: "location.north.line.fill")
                        .font(.subheadline)
                    Text("Track Live")
                        .font(.subheadline.weight(.bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(hex: 0x113B70), Color(hex: 0x0B2347)]
                    : [Color(red: 0.0, green: 0.5, blue: 1.0), Color(red: 0.05, green: 0.3, blue: 0.95)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.gray, lineWidth: 1)
        )
    }

    private func getTripProgress(for trip: Trip) -> Double {
        let elapsed = Date().timeIntervalSince(trip.startTime)
        let totalDuration: TimeInterval = 8 * 3600
        let ratio = elapsed / totalDuration
        return min(max(ratio, 0.18), 0.92)
    }

    private func getTripDistances(for trip: Trip) -> (covered: Int, left: Int) {
        let progress = getTripProgress(for: trip)
        let totalDist = 450
        let covered = Int(Double(totalDist) * progress)
        let left = totalDist - covered
        return (covered, left)
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        return formatter.string(from: date)
    }
}

struct FleetStatusCard: View {
    @Environment(\.colorScheme) var colorScheme
    var title: String
    var systemImage: String
    var titleTint: Color
    var metrics: [(String, String, String, Color)]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(titleTint)
                    .frame(width: 44, height: 44)
                    .background(titleTint.opacity(0.12))
                    .clipShape(Circle())
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.gray)
            }
            
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.primary)
            
            VStack(spacing: 12) {
                ForEach(metrics, id: \.2) { metric in
                    HStack(spacing: 12) {
                        Image(systemName: metric.0)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(metric.3)
                            .frame(width: 28, height: 28)
                            .background(metric.3.opacity(0.12))
                            .clipShape(Circle())
                        
                        Text(metric.2.capitalized)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.gray)
                        
                        Spacer()
                        
                        Text(metric.1)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(metric.3)
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 240)
        .background(colorScheme == .dark ? Color(white: 0.12) : Color.white)
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.gray.opacity(colorScheme == .dark ? 0.3 : 0.15), lineWidth: 1)
        )
    }
}

private struct DashboardMaintenanceRow: View {
    var task: MaintenanceTask
    var assignee: User?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            IconBubble(
                systemImage: task.isUrgent ? "exclamationmark.triangle.fill" : "wrench.and.screwdriver.fill",
                tint: task.isUrgent ? FleetPalette.danger : FleetPalette.warning
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(task.description)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(FleetPalette.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(FleetManagerFormat.day.string(from: task.scheduledDate.date))
                    Text("•")
                    Text(assignee.map { "\($0.displayName)" } ?? "Unassigned")
                }
                .font(.caption)
                .foregroundStyle(FleetPalette.textSecondary)
            }

            Spacer()

            Text(task.status.title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(FleetPalette.maintenanceStatus(task.status))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(FleetPalette.maintenanceStatus(task.status).opacity(0.12))
                .clipShape(Capsule())
        }
        .contentShape(Rectangle())
    }
}

private struct DashboardDriverStatusListView: View {
    @ObservedObject var usersViewModel: UserManagementViewModel
    @ObservedObject var tripsViewModel: TripManagementViewModel
    @ObservedObject var maintenanceViewModel: MaintenanceViewModel
    var activeDrivers: [Driver]
    var availableDrivers: [Driver]
    var offDutyDrivers: [Driver]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeader(title: "Drivers")
                driverSection(title: "Active", drivers: activeDrivers, color: FleetPalette.success)
                driverSection(title: "Available", drivers: availableDrivers, color: FleetPalette.accent)
                driverSection(title: "Off Duty", drivers: offDutyDrivers, color: FleetPalette.neutral)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .fleetScreenBackground()
        .navigationTitle("Driver Status")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func driverSection(title: String, drivers: [Driver], color: Color) -> some View {
        if drivers.isEmpty == false {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    DashboardSectionTitle(title)
                    Spacer()
                    Text("\(drivers.count)")
                        .font(.caption.weight(.bold))
                        .foregroundColor(color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(color.opacity(0.12))
                        .clipShape(Capsule())
                }

                GlassPanel(hasBorder: false) {
                    VStack(spacing: 14) {
                        ForEach(drivers) { driver in
                            if let driverUser = usersViewModel.user(for: driver.userId) {
                                NavigationLink {
                                    ManagerUserDetailView(
                                        user: driverUser,
                                        viewModel: usersViewModel,
                                        tripsViewModel: tripsViewModel,
                                        maintenanceViewModel: maintenanceViewModel
                                    )
                                } label: {
                                    DriverStatusRow(driver: driver, user: driverUser, color: color)
                                }
                                .buttonStyle(.plain)
                            } else {
                                DriverStatusRow(driver: driver, user: nil, color: color)
                            }

                            if driver.id != drivers.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct DashboardVehicleStatusListView: View {
    @ObservedObject var usersViewModel: UserManagementViewModel
    @ObservedObject var vehiclesViewModel: VehicleViewModel
    @ObservedObject var maintenanceViewModel: MaintenanceViewModel
    var onTripVehicles: [Vehicle]
    var availableVehicles: [Vehicle]
    var maintenanceVehicles: [Vehicle]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeader(title: "Vehicles")
                vehicleSection(title: "On Trip", vehicles: onTripVehicles, color: FleetPalette.success)
                vehicleSection(title: "Available", vehicles: availableVehicles, color: FleetPalette.accent)
                vehicleSection(title: "Maintenance", vehicles: maintenanceVehicles, color: FleetPalette.warning)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .fleetScreenBackground()
        .navigationTitle("Vehicle Status")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func vehicleSection(title: String, vehicles: [Vehicle], color: Color) -> some View {
        if vehicles.isEmpty == false {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    DashboardSectionTitle(title)
                    Spacer()
                    Text("\(vehicles.count)")
                        .font(.caption.weight(.bold))
                        .foregroundColor(color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(color.opacity(0.12))
                        .clipShape(Capsule())
                }

                GlassPanel(hasBorder: false) {
                    VStack(spacing: 14) {
                        ForEach(vehicles) { vehicle in
                            NavigationLink {
                                ManagerVehicleDetailView(
                                    vehicle: vehicle,
                                    viewModel: vehiclesViewModel,
                                    usersViewModel: usersViewModel,
                                    maintenanceViewModel: maintenanceViewModel,
                                    openMaintenanceRequest: { _ in }
                                )
                            } label: {
                                VehicleStatusRow(
                                    vehicle: vehicle,
                                    driver: usersViewModel.driverUser(for: vehicle.driverId),
                                    color: color
                                )
                            }
                            .buttonStyle(.plain)

                            if vehicle.id != vehicles.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct DriverStatusRow: View {
    var driver: Driver
    var user: User?
    var color: Color

    var body: some View {
        HStack(spacing: 14) {
            AvatarView(name: user?.displayName ?? driver.licenceNum, role: .driver, size: 46, imageURL: user?.avatarImageURL)

            VStack(alignment: .leading, spacing: 4) {
                Text(user?.displayName ?? "Driver")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(FleetPalette.textPrimary)

                HStack(spacing: 6) {
                    Image(systemName: "truck.box.fill")
                        .font(.caption)
                    Text("\(driver.vehicleType.capitalized) • \(driver.licenceNum)")
                        .font(.caption.weight(.medium))
                }
                .foregroundColor(FleetPalette.textSecondary)
            }

            Spacer()

            Text(driver.status.title.uppercased())
                .font(.system(size: 10, weight: .black))
                .foregroundColor(FleetPalette.personnelStatus(driver.status))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(FleetPalette.personnelStatus(driver.status).opacity(0.12))
                .clipShape(Capsule())
        }
    }
}

private struct VehicleStatusRow: View {
    var vehicle: Vehicle
    var driver: User?
    var color: Color

    var body: some View {
        HStack(spacing: 14) {
            VehicleAssetImage(vehicle: vehicle, width: 64, height: 50, cornerRadius: 14)

            VStack(alignment: .leading, spacing: 4) {
                Text(vehicle.licencePlate)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(FleetPalette.textPrimary)

                Text("\(vehicle.year) \(vehicle.make) \(vehicle.model)")
                    .font(.caption)
                    .foregroundColor(FleetPalette.textSecondary)

                HStack(spacing: 4) {
                    Image(systemName: "person.circle.fill")
                        .font(.caption2)
                    Text(driver?.displayName ?? "Unassigned")
                        .font(.caption2.weight(.medium))
                }
                .foregroundColor(FleetPalette.textSecondary)
            }

            Spacer()

            Text(vehicle.status.title.uppercased())
                .font(.system(size: 10, weight: .black))
                .foregroundColor(color)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(color.opacity(0.12))
                .clipShape(Capsule())
        }
    }
}

private struct DashboardMaintenanceStatusListView: View {
    @ObservedObject var usersViewModel: UserManagementViewModel
    @ObservedObject var vehiclesViewModel: VehicleViewModel
    @ObservedObject var maintenanceViewModel: MaintenanceViewModel
    var openTasks: [MaintenanceTask]
    var inProgressTasks: [MaintenanceTask]
    var completedTasks: [MaintenanceTask]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeader(title: "Maintenance")
                maintenanceSection(title: "Open", tasks: openTasks, color: FleetPalette.warning)
                maintenanceSection(title: "In Progress", tasks: inProgressTasks, color: FleetPalette.accent)
                maintenanceSection(title: "Completed", tasks: completedTasks, color: FleetPalette.success)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .fleetScreenBackground()
        .navigationTitle("Maintenance Status")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func maintenanceSection(title: String, tasks: [MaintenanceTask], color: Color) -> some View {
        if tasks.isEmpty == false {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    DashboardSectionTitle(title)
                    Spacer()
                    Text("\(tasks.count)")
                        .font(.caption.weight(.bold))
                        .foregroundColor(color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(color.opacity(0.12))
                        .clipShape(Capsule())
                }

                GlassPanel(hasBorder: false) {
                    VStack(spacing: 14) {
                        ForEach(tasks) { task in
                            NavigationLink {
                                ManagerServiceDetailView(
                                    task: task,
                                    viewModel: maintenanceViewModel,
                                    vehiclesViewModel: vehiclesViewModel,
                                    usersViewModel: usersViewModel
                                )
                            } label: {
                                DashboardMaintenanceRow(
                                    task: task,
                                    assignee: usersViewModel.personnelUser(for: task.executedBy)
                                )
                            }
                            .buttonStyle(.plain)

                            if task.id != tasks.last?.id {
                                Divider()
                            }
                        }
                    }
                    .padding(4)
                }
            }
        }
    }
}

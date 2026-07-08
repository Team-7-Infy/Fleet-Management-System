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
    var onSelectDriversTab: (() -> Void)?
    var onSelectVehiclesTab: (() -> Void)?
    var onSelectMaintenanceTab: (() -> Void)?
    @State private var selectedActiveTripID: UUID?

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
        usersViewModel.drivers
            .filter { $0.status == .active && busyDriverIDs.contains($0.id) == false }
    }

    private var enrouteDrivers: [Driver] {
        usersViewModel.drivers.filter { busyDriverIDs.contains($0.id) }
    }

    private var offDutyDrivers: [Driver] {
        usersViewModel.drivers.filter { $0.status != .active }
    }

    private var availableVehicles: [Vehicle] {
        vehiclesViewModel.vehicles.filter { $0.status == .available && $0.driverId == nil }
    }

    private var enrouteVehicles: [Vehicle] {
        vehiclesViewModel.vehicles.filter { $0.status == .available && $0.driverId != nil }
    }

    private var maintenanceVehicles: [Vehicle] {
        vehiclesViewModel.maintenanceVehicles
    }

    private var scheduledTasksCount: Int {
        maintenanceViewModel.openTasks.filter { $0.status == .scheduled || $0.status == .assigned }.count
    }

    private var inProgressTasksCount: Int {
        maintenanceViewModel.openTasks.filter { $0.status == .inProgress }.count
    }

    private var onHoldTasksCount: Int {
        maintenanceViewModel.openTasks.filter { $0.status == .onHold }.count
    }

    var body: some View {
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
        .fleetScreenBackground()
        .refreshable {
            await refresh()
        }
        .task {
            await refresh()
        }
    }

    private var headerBar: some View {
        HStack(alignment: .center) {
            ScreenHeader(title: "Live")
            Spacer()
            NotificationBadge(unreadCount: notificationViewModel.unreadCount) {
                showingNotifications = true
            }
            .padding(.trailing, 4)
            if let onProfile {
                Button(action: onProfile) {
                    profileIcon
                }
                .accessibilityLabel("Account")
            }
        }
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
                        .frame(width: 36, height: 36)
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
        Image(systemName: "person.crop.circle")
            .font(.title2.weight(.semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(FleetPalette.primary)
            .frame(width: 36, height: 36)
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
        VStack(alignment: .leading, spacing: 10) {
            DashboardSectionTitle("Fleet Status")

            GlassPanel(hasBorder: false) {
                VStack(spacing: 0) {
                    Button {
                        onSelectDriversTab?()
                    } label: {
                        FleetStatusRowContent(
                            title: "Drivers",
                            systemImage: "person.2.fill",
                            tint: FleetPalette.accent,
                            metrics: [
                                ("Active", "\(enrouteDrivers.count)", FleetPalette.success),
                                ("Available", "\(availableDrivers.count)", FleetPalette.accent),
                                ("Off duty", "\(offDutyDrivers.count)", FleetPalette.neutral)
                            ]
                        )
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .padding(.vertical, 4)

                    Button {
                        onSelectVehiclesTab?()
                    } label: {
                        FleetStatusRowContent(
                            title: "Vehicles",
                            systemImage: "car.2.fill",
                            tint: FleetPalette.accent,
                            metrics: [
                                ("On trip", "\(enrouteVehicles.count)", FleetPalette.success),
                                ("Available", "\(availableVehicles.count)", FleetPalette.accent),
                                ("Maintenance", "\(maintenanceVehicles.count)", FleetPalette.warning)
                            ]
                        )
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .padding(.vertical, 4)

                    Button {
                        onSelectMaintenanceTab?()
                    } label: {
                        FleetStatusRowContent(
                            title: "Maintenance",
                            systemImage: "wrench.and.screwdriver.fill",
                            tint: FleetPalette.accent,
                            metrics: [
                                ("Scheduled", "\(scheduledTasksCount)", Color(hex: 0xB58A00)),
                                ("Active", "\(inProgressTasksCount)", FleetPalette.success),
                                ("On hold", "\(onHoldTasksCount)", FleetPalette.danger)
                            ]
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var maintenanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                DashboardSectionTitle("Maintenance")
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(Color(hex: 0xB58A00)).frame(width: 6, height: 6)
                    Text("\(maintenanceViewModel.openTasks.count) open")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: 0xB58A00))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(FleetPalette.warning.opacity(0.12))
                .clipShape(Capsule())
            }
            .padding(.horizontal, 2)

            VStack(spacing: 10) {
                if maintenanceViewModel.openTasks.isEmpty {
                    GlassPanel(hasBorder: false) {
                        EmptyStateView(
                            title: "No Open Maintenance",
                            message: "All vehicles are serviced and ready.",
                            systemImage: "wrench.and.screwdriver"
                        )
                        .padding(.vertical, 20)
                    }
                } else {
                    ForEach(Array(maintenanceViewModel.openTasks.prefix(3).enumerated()), id: \.element.id) { index, task in
                        DashboardMaintenanceRow(
                            task: task,
                            assignee: usersViewModel.personnelUser(for: task.executedBy)
                        )
                    }
                }
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
                colors: [Color(hex: 0x007AFF), Color(hex: 0x004CE5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(24)
    }
}

struct ActiveTripGradientCard: View {
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
                    Text(tripTimingString(for: trip))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
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
                colors: [Color(hex: 0x007AFF), Color(hex: 0x004CE5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(24)
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

    private func tripTimingString(for trip: Trip) -> String {
        let startStr = formattedTime(trip.startTime)
        let endStr = formattedTime(trip.endTime ?? trip.startTime.addingTimeInterval(8 * 3600))
        return "\(startStr) - \(endStr)"
    }
}

struct FleetStatusRowContent: View {
    var title: String
    var systemImage: String
    var tint: Color
    var metrics: [(String, String, Color)]

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .center, spacing: 6) {
                IconBubble(systemImage: systemImage, tint: tint)
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(FleetPalette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 88, alignment: .center)

            Divider()
                .padding(.vertical, 4)

            HStack(spacing: 4) {
                ForEach(metrics, id: \.0) { metric in
                    VStack(spacing: 4) {
                        Text(metric.0.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(FleetPalette.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        Text(metric.1)
                            .font(.system(size: 19, weight: .heavy, design: .rounded))
                            .foregroundStyle(metric.2)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(FleetPalette.textSecondary)
        }
        .padding(.vertical, 8)
    }
}

private struct DashboardMaintenanceRow: View {
    var task: MaintenanceTask
    var assignee: User?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack(alignment: .topTrailing) {
                IconBubble(
                    systemImage: task.isUrgent ? "exclamationmark.triangle.fill" : "wrench.and.screwdriver.fill",
                    tint: task.isUrgent ? FleetPalette.danger : FleetPalette.warning
                )
                
                if task.isUrgent {
                    Circle()
                        .fill(FleetPalette.danger)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                        .offset(x: 1, y: -1)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(task.description)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(FleetPalette.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Image(systemName: "calendar")
                            .font(.system(size: 9))
                        Text(FleetManagerFormat.day.string(from: task.scheduledDate.date))
                    }
                    Text("•")
                    HStack(spacing: 3) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 9))
                        Text(assignee.map { "\($0.displayName)" } ?? "Unassigned")
                    }
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(FleetPalette.textPrimary.opacity(0.55))
            }

            Spacer(minLength: 8)

            let pillColor = statusColor(for: task.status)
            HStack(spacing: 4) {
                Circle()
                    .fill(pillColor)
                    .frame(width: 5, height: 5)
                Text(task.status.title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(pillColor)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(pillColor.opacity(0.08))
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(pillColor.opacity(0.12), lineWidth: 1)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(FleetPalette.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(FleetPalette.tertiary.opacity(0.06), lineWidth: 1)
        }
    }

    private func statusColor(for status: MaintenanceTaskStatus) -> Color {
        switch status {
        case .scheduled, .onHold:
            return Color(hex: 0xB58A00) // Highly legible dark amber
        default:
            return FleetPalette.maintenanceStatus(status)
        }
    }
}

private struct DashboardDriverStatusListView: View {
    @ObservedObject var usersViewModel: UserManagementViewModel
    @ObservedObject var vehiclesViewModel: VehicleViewModel
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
                                        vehiclesViewModel: vehiclesViewModel,
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
                .foregroundColor(color)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(color.opacity(0.12))
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

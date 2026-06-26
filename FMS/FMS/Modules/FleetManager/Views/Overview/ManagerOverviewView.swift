import SwiftUI

struct ManagerOverviewView: View {
    @ObservedObject var usersViewModel: UserManagementViewModel
    @ObservedObject var vehiclesViewModel: VehicleViewModel
    @ObservedObject var tripsViewModel: TripManagementViewModel
    @ObservedObject var maintenanceViewModel: MaintenanceViewModel

    var quickAddTrip: () -> Void
    var quickMaintenance: () -> Void
    var refresh: () async -> Void

    private var activeTrips: [Trip] {
        tripsViewModel.trips
            .filter { $0.status == .accepted }
            .sorted { $0.startTime < $1.startTime }
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
        Set(activeTrips.map(\.driverId))
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
        vehiclesViewModel.vehicles.filter { $0.status == .active && $0.driverId == nil }
    }

    private var enrouteVehicles: [Vehicle] {
        vehiclesViewModel.vehicles.filter { $0.status == .active && $0.driverId != nil }
    }

    private var maintenanceVehicles: [Vehicle] {
        vehiclesViewModel.maintenanceVehicles
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScreenHeader(title: "Live")
                tripStatusCard
                fleetStatusSection
                maintenanceSection
                actionsSection
            }
            .padding()
            .padding(.bottom, 10)
        }
        .fleetScreenBackground()
        .refreshable {
            await refresh()
        }
    }

    private var tripStatusCard: some View {
        DashboardTripStatusCard(
            activeTrips: activeTrips,
            pendingTrips: pendingTrips,
            completedTrips: completedTrips
        )
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            DashboardSectionTitle("Actions")

            LazyVGrid(columns: FleetPalette.twoColumnGrid, spacing: 12) {
                DashboardActionButton(
                    title: "Quick Add Trip",
                    detail: "Assign driver",
                    systemImage: "plus.circle.fill",
                    tint: FleetPalette.primary,
                    action: quickAddTrip
                )

                DashboardActionButton(
                    title: "Quick Maintenance",
                    detail: "\(maintenanceVehicles.count) vehicles",
                    systemImage: "wrench.and.screwdriver.fill",
                    tint: FleetPalette.warning,
                    action: quickMaintenance
                )
            }
        }
    }

    private var fleetStatusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            DashboardSectionTitle("Fleet Status")

            LazyVGrid(columns: FleetPalette.twoColumnGrid, spacing: 12) {
                NavigationLink {
                    DashboardDriverStatusListView(
                        usersViewModel: usersViewModel,
                        activeDrivers: enrouteDrivers,
                        availableDrivers: availableDrivers,
                        offDutyDrivers: offDutyDrivers
                    )
                } label: {
                    DashboardMetricCard(
                        title: "Drivers",
                        systemImage: "person.2.fill",
                        tint: FleetPalette.primary,
                        metrics: [
                            ("Active", "\(enrouteDrivers.count)"),
                            ("Available", "\(availableDrivers.count)"),
                            ("Off duty", "\(offDutyDrivers.count)")
                        ]
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    DashboardVehicleStatusListView(
                        usersViewModel: usersViewModel,
                        onTripVehicles: enrouteVehicles,
                        availableVehicles: availableVehicles,
                        maintenanceVehicles: maintenanceVehicles
                    )
                } label: {
                    DashboardMetricCard(
                        title: "Vehicles",
                        systemImage: "car.2.fill",
                        tint: FleetPalette.primary,
                        metrics: [
                            ("On trip", "\(enrouteVehicles.count)"),
                            ("Available", "\(availableVehicles.count)"),
                            ("Maintenance", "\(maintenanceVehicles.count)")
                        ]
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var maintenanceSection: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Maintenance", systemImage: "calendar.badge.clock")
                        .font(.headline.weight(.bold))
                    Spacer()
                    StatusPill(text: "\(maintenanceViewModel.openTasks.count) open", color: FleetPalette.warning)
                }

                if maintenanceViewModel.openTasks.isEmpty {
                    Text("No open maintenance tasks.")
                        .font(.subheadline)
                        .foregroundStyle(FleetPalette.textSecondary)
                } else {
                    ForEach(Array(maintenanceViewModel.openTasks.prefix(3))) { task in
                        DashboardMaintenanceRow(
                            task: task,
                            assignee: usersViewModel.personnelUser(for: task.executedBy)
                        )
                        if task.id != maintenanceViewModel.openTasks.prefix(3).last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

private struct DashboardTripStatusCard: View {
    var activeTrips: [Trip]
    var pendingTrips: [Trip]
    var completedTrips: [Trip]

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Trip Status")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(FleetPalette.primary)
                        Text(activeTrips.isEmpty ? "No live trip" : "\(activeTrips.count) live")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(FleetPalette.textPrimary)
                    }

                    Spacer()

                    IconBubble(
                        systemImage: activeTrips.isEmpty ? "location.slash" : "location.north.line.fill",
                        tint: activeTrips.isEmpty ? FleetPalette.neutral : FleetPalette.primary
                    )
                }

                LazyVGrid(columns: FleetPalette.twoColumnGrid, spacing: 10) {
                    MiniMetric(title: "Pending", value: "\(pendingTrips.count)", tint: FleetPalette.warning)
                    MiniMetric(title: "Completed", value: "\(completedTrips.count)", tint: FleetPalette.success)
                }

                if let trip = activeTrips.first {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Current route")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(FleetPalette.textSecondary)
                        Text("\(trip.startLocation) to \(trip.endLocation)")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(FleetPalette.textPrimary)
                            .lineLimit(2)
                        Text(FleetManagerFormat.shortDateTime.string(from: trip.startTime))
                            .font(.caption)
                            .foregroundStyle(FleetPalette.textSecondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(FleetPalette.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }
}

private struct MiniMetric: View {
    var title: String
    var value: String
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(FleetPalette.textSecondary)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(tint)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FleetPalette.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct DashboardMaintenanceRow: View {
    var task: MaintenanceTask
    var assignee: User?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            IconBubble(
                systemImage: task.isUrgent ? "exclamationmark.triangle.fill" : "wrench.and.screwdriver.fill",
                tint: task.isUrgent ? FleetPalette.danger : FleetPalette.warning
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(task.description)
                    .font(.headline)
                    .foregroundStyle(FleetPalette.textPrimary)
                    .lineLimit(2)
                Text(FleetManagerFormat.day.string(from: task.scheduledDate.date))
                    .font(.subheadline)
                    .foregroundStyle(FleetPalette.textSecondary)
                Text(assignee.map { "Assigned to \($0.displayName)" } ?? "Unassigned")
                    .font(.caption)
                    .foregroundStyle(FleetPalette.textSecondary)
            }

            Spacer()

            StatusPill(text: task.status.title, color: FleetPalette.maintenanceStatus(task.status))
        }
    }
}

private struct DashboardDriverStatusListView: View {
    @ObservedObject var usersViewModel: UserManagementViewModel
    var activeDrivers: [Driver]
    var availableDrivers: [Driver]
    var offDutyDrivers: [Driver]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScreenHeader(title: "Drivers")
                driverSection(title: "Active", drivers: activeDrivers)
                driverSection(title: "Available", drivers: availableDrivers)
                driverSection(title: "Off Duty", drivers: offDutyDrivers)
            }
            .padding()
        }
        .fleetScreenBackground()
        .navigationTitle("Driver Status")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func driverSection(title: String, drivers: [Driver]) -> some View {
        if drivers.isEmpty == false {
            VStack(alignment: .leading, spacing: 8) {
                DashboardSectionTitle(title)
                GlassPanel {
                    VStack(spacing: 12) {
                        ForEach(drivers) { driver in
                            DriverStatusRow(driver: driver, user: usersViewModel.user(for: driver.userId))
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
    var onTripVehicles: [Vehicle]
    var availableVehicles: [Vehicle]
    var maintenanceVehicles: [Vehicle]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScreenHeader(title: "Vehicles")
                vehicleSection(title: "On Trip", vehicles: onTripVehicles)
                vehicleSection(title: "Available", vehicles: availableVehicles)
                vehicleSection(title: "Maintenance", vehicles: maintenanceVehicles)
            }
            .padding()
        }
        .fleetScreenBackground()
        .navigationTitle("Vehicle Status")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func vehicleSection(title: String, vehicles: [Vehicle]) -> some View {
        if vehicles.isEmpty == false {
            VStack(alignment: .leading, spacing: 8) {
                DashboardSectionTitle(title)
                GlassPanel {
                    VStack(spacing: 12) {
                        ForEach(vehicles) { vehicle in
                            VehicleStatusRow(
                                vehicle: vehicle,
                                driver: usersViewModel.driverUser(for: vehicle.driverId)
                            )
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

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(name: user?.displayName ?? driver.licenceNum, role: .driver, size: 48, imageURL: user?.avatarImageURL)

            VStack(alignment: .leading, spacing: 4) {
                Text(user?.displayName ?? "Driver")
                    .font(.headline)
                Text("\(driver.vehicleType.capitalized) - \(driver.licenceNum)")
                    .font(.subheadline)
                    .foregroundStyle(FleetPalette.textSecondary)
            }

            Spacer()

            StatusPill(text: driver.status.title, color: driver.status == .active ? FleetPalette.success : FleetPalette.neutral)
        }
    }
}

private struct VehicleStatusRow: View {
    var vehicle: Vehicle
    var driver: User?

    var body: some View {
        HStack(spacing: 12) {
            IconBubble(systemImage: vehicleIcon, tint: FleetPalette.primary)

            VStack(alignment: .leading, spacing: 4) {
                Text(vehicle.licencePlate)
                    .font(.headline)
                Text("\(vehicle.year) \(vehicle.make) \(vehicle.model)")
                    .font(.subheadline)
                    .foregroundStyle(FleetPalette.textSecondary)
                Text(driver.map { "Driver: \($0.displayName)" } ?? "Driver: Unassigned")
                    .font(.caption)
                    .foregroundStyle(FleetPalette.textSecondary)
            }

            Spacer()

            StatusPill(text: vehicle.status.title, color: FleetPalette.vehicleStatus(vehicle.status))
        }
    }

    private var vehicleIcon: String {
        vehicle.vehicleType.localizedCaseInsensitiveContains("bus") ? "bus.fill" : "car.fill"
    }
}

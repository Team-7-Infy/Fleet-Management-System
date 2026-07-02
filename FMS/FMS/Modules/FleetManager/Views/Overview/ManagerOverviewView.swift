import SwiftUI

struct ManagerOverviewView: View {
    @ObservedObject var usersViewModel: UserManagementViewModel
    @ObservedObject var vehiclesViewModel: VehicleViewModel
    @ObservedObject var tripsViewModel: TripManagementViewModel
    @ObservedObject var maintenanceViewModel: MaintenanceViewModel
    @ObservedObject var notificationController: ManagerNotificationController

    var refresh: () async -> Void
    var currentUserId: UUID?
    var onProfile: (() -> Void)?
    @State private var isShowingNotifications = false

    private var activeTrips: [Trip] {
        tripsViewModel.trips
            .filter { $0.status == .accepted || $0.status == .inProgress }
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
                tripStatusCard
                fleetStatusSection
                maintenanceSection
            }
            .padding()
            .padding(.bottom, 10)
        }
        .fleetScreenBackground()
        .refreshable {
            await refresh()
        }
        .navigationTitle("Live")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    isShowingNotifications = true
                } label: {
                    NotificationToolbarIcon(count: notificationController.unreadCount)
                }
                .accessibilityLabel("Notifications")

                if let onProfile {
                    Button(action: onProfile) {
                        ProfileToolbarIcon(user: currentUserId.flatMap { usersViewModel.user(for: $0) })
                    }
                    .accessibilityLabel("Account")
                }
            }
        }
        .sheet(isPresented: $isShowingNotifications) {
            NavigationStack {
                ManagerNotificationsView(
                    controller: notificationController,
                    usersViewModel: usersViewModel,
                    recipientId: currentUserId
                )
            }
        }
    }

    private var tripStatusCard: some View {
        DashboardTripStatusCard(
            activeTrips: activeTrips,
            pendingTrips: pendingTrips,
            completedTrips: completedTrips
        )
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
                        tint: FleetPalette.accent,
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
                        tint: FleetPalette.accent,
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
                    HStack(spacing: 6) {
                        StatusDot(text: "Open", color: FleetPalette.warning, size: 12)
                        Text("\(maintenanceViewModel.openTasks.count) open")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(FleetPalette.textSecondary)
                    }
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

private struct NotificationToolbarIcon: View {
    var count: Int

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: count > 0 ? "bell.badge.fill" : "bell")
                .font(.title3.weight(.semibold))
                .symbolRenderingMode(.hierarchical)

            if count > 0 {
                Text(count > 99 ? "99+" : "\(count)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .frame(minWidth: 16, minHeight: 16)
                    .background(FleetPalette.danger, in: Capsule())
                    .offset(x: 7, y: -7)
            }
        }
        .frame(width: 30, height: 30)
    }
}

private struct ProfileToolbarIcon: View {
    var user: User?

    var body: some View {
        if let imageURL = user?.avatarImageURL {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 30, height: 30)
                        .clipShape(Circle())
                default:
                    fallback
                }
            }
        } else {
            fallback
        }
    }

    private var fallback: some View {
        Image(systemName: "person.crop.circle")
            .font(.title2.weight(.semibold))
            .symbolRenderingMode(.hierarchical)
            .frame(width: 30, height: 30)
    }
}

private struct ManagerNotificationsView: View {
    @ObservedObject var controller: ManagerNotificationController
    @ObservedObject var usersViewModel: UserManagementViewModel
    var recipientId: UUID?

    @State private var searchText = ""
    @State private var isSelecting = false
    @State private var selectedIds: Set<UUID> = []

    private var visibleNotifications: [FleetNotification] {
        controller.notifications(searchText: searchText)
    }

    var body: some View {
        ZStack {
            FleetPalette.surface.ignoresSafeArea()

            if controller.isLoading && controller.notifications.isEmpty {
                ProgressView()
                    .tint(FleetPalette.accent)
            } else if visibleNotifications.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(visibleNotifications) { notification in
                        Button {
                            handleTap(notification)
                        } label: {
                            ManagerNotificationRow(
                                notification: notification,
                                sender: sender(for: notification),
                                imageURL: usersViewModel.user(for: notification.actorUserId)?.avatarImageURL,
                                isSelecting: isSelecting,
                                isSelected: selectedIds.contains(notification.id)
                            )
                        }
                        .buttonStyle(.plain)
                        .listRowSeparatorTint(Color.black.opacity(0.08))
                        .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 14))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle(controller.selectedFilter == .all ? "Notifications" : controller.selectedFilter.title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search notifications")
        .safeAreaInset(edge: .bottom) {
            if isSelecting {
                selectionBar
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(isSelecting ? "Done" : "Edit") {
                    withAnimation(.snappy) {
                        isSelecting.toggle()
                        selectedIds.removeAll()
                    }
                }
                .fontWeight(.semibold)
                .disabled(controller.notifications.isEmpty)
            }

            ToolbarItem(placement: .topBarTrailing) {
                if isSelecting {
                    Button("Select All") {
                        selectedIds = Set(visibleNotifications.map(\.id))
                    }
                    .fontWeight(.semibold)
                    .disabled(visibleNotifications.isEmpty)
                } else {
                    Menu {
                        Picker("Filter", selection: $controller.selectedFilter) {
                            ForEach(FleetNotificationFilter.allCases) { filter in
                                Label(filter.title, systemImage: filter.systemImage)
                                    .tag(filter)
                            }
                        }

                        Divider()

                        Button("Clear Filter", systemImage: "xmark.circle") {
                            controller.selectedFilter = .all
                            selectedIds.removeAll()
                        }
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                    .labelStyle(.iconOnly)
                    .accessibilityLabel("Filter notifications")
                }
            }
        }
        .refreshable {
            await controller.load(recipientId: recipientId)
        }
        .task {
            await controller.load(recipientId: recipientId)
        }
    }

    private var emptyState: some View {
        Group {
            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ContentUnavailableView(
                    "No notifications",
                    systemImage: "bell.slash",
                    description: Text("Fleet alerts, service updates, and trip requests will appear here.")
                )
            } else {
                ContentUnavailableView.search
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var selectionBar: some View {
        HStack(spacing: 12) {
            Button(selectedIds.isEmpty ? "Read All" : "Read Selected") {
                Task {
                    await markSelectedOrAllRead()
                }
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
    }

    private func sender(for notification: FleetNotification) -> String {
        if let user = usersViewModel.user(for: notification.actorUserId) {
            return user.displayName
        }

        switch notification.category {
        case .system:
            return "Fleet System"
        default:
            return notification.category.title
        }
    }

    private func handleTap(_ notification: FleetNotification) {
        if isSelecting {
            if selectedIds.contains(notification.id) {
                selectedIds.remove(notification.id)
            } else {
                selectedIds.insert(notification.id)
            }
            return
        }

        Task {
            await controller.markRead(notification)
        }
    }

    private func markSelectedOrAllRead() async {
        if selectedIds.isEmpty {
            await controller.markAllRead()
        } else {
            let selectedNotifications = visibleNotifications.filter { selectedIds.contains($0.id) }
            for notification in selectedNotifications {
                await controller.markRead(notification)
            }
        }

        withAnimation(.snappy) {
            selectedIds.removeAll()
            isSelecting = false
        }
    }
}

private struct ManagerNotificationRow: View {
    var notification: FleetNotification
    var sender: String
    var imageURL: URL?
    var isSelecting: Bool
    var isSelected: Bool

    private var preview: String {
        "\(notification.title): \(notification.message)"
    }

    var body: some View {
        HStack(spacing: 14) {
            if isSelecting {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(isSelected ? FleetPalette.accent : FleetPalette.textSecondary)
                    .frame(width: 26)
            }

            notificationAvatar

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(sender)
                        .font(.headline.weight(notification.isRead ? .semibold : .bold))
                        .foregroundStyle(FleetPalette.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    if notification.isRead == false {
                        Circle()
                            .fill(FleetPalette.accent)
                            .frame(width: 8, height: 8)
                    }
                    Text(ManagerNotificationDateFormatter.short.string(from: notification.createdAt))
                        .font(.subheadline)
                        .foregroundStyle(FleetPalette.textSecondary)
                }

                Text(preview)
                    .font(.subheadline.weight(notification.isRead ? .regular : .medium))
                    .foregroundStyle(FleetPalette.textSecondary)
                    .lineLimit(2)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.black.opacity(0.18))
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var notificationAvatar: some View {
        if let imageURL {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    avatarFallback
                }
            }
            .frame(width: 58, height: 58)
            .clipShape(Circle())
        } else {
            avatarFallback
        }
    }

    private var avatarFallback: some View {
        Image(systemName: notification.category.systemImage)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 58, height: 58)
            .background(notification.category.tint.gradient, in: Circle())
    }
}

private enum ManagerNotificationDateFormatter {
    static let short: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yy"
        return formatter
    }()
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
                            .foregroundStyle(FleetPalette.accent)
                        Text(activeTrips.isEmpty ? "No live trip" : "\(activeTrips.count) live")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(FleetPalette.textPrimary)
                    }

                    Spacer()

                    IconBubble(
                        systemImage: activeTrips.isEmpty ? "location.slash" : "location.north.line.fill",
                        tint: activeTrips.isEmpty ? FleetPalette.neutral : FleetPalette.accent
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

            StatusDot(text: task.status.title, color: FleetPalette.maintenanceStatus(task.status))
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

            StatusDot(text: driver.status.title, color: FleetPalette.personnelStatus(driver.status))
        }
    }
}

private struct VehicleStatusRow: View {
    var vehicle: Vehicle
    var driver: User?

    var body: some View {
        HStack(spacing: 12) {
            VehicleAssetImage(vehicle: vehicle, width: 64, height: 50, cornerRadius: 14)

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

            StatusDot(text: vehicle.status.title, color: FleetPalette.vehicleStatus(vehicle.status))
        }
    }
}

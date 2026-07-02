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
            VStack(alignment: .leading, spacing: 22) {
                activeTripsHeaderCard
                tripMetricsRow
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

    private var activeTripsHeaderCard: some View {
        Group {
            if activeTrips.isEmpty {
                FleetStatusOverviewGradientCard()
            } else {
                TabView {
                    ForEach(activeTrips) { trip in
                        ActiveTripGradientCard(
                            trip: trip,
                            tripsViewModel: tripsViewModel,
                            vehiclesViewModel: vehiclesViewModel,
                            usersViewModel: usersViewModel
                        )
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                .frame(height: 310)
            }
        }
    }
    
    private var tripMetricsRow: some View {
        let total = activeTrips.count + pendingTrips.count + completedTrips.count
        let completedProgress = total > 0 ? Double(completedTrips.count) / Double(total) : 0.0
        let pendingProgress = total > 0 ? Double(pendingTrips.count) / Double(total) : 0.0
        
        return HStack(spacing: 12) {
            FMSMetricWidget(
                title: "Pending Trips",
                value: "\(pendingTrips.count)",
                subtitle: pendingTrips.count == 1 ? "Awaiting driver" : "Awaiting drivers",
                progress: pendingProgress,
                color: FleetPalette.warning
            )
            
            FMSMetricWidget(
                title: "Completed Trips",
                value: "\(completedTrips.count)",
                subtitle: "Finished today",
                progress: completedProgress,
                color: FleetPalette.success
            )
        }
    }

    private var fleetStatusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            DashboardSectionTitle("Fleet Status")

            GlassPanel(hasBorder: false) {
                VStack(spacing: 0) {
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

                    NavigationLink {
                        DashboardVehicleStatusListView(
                            usersViewModel: usersViewModel,
                            vehiclesViewModel: vehiclesViewModel,
                            onTripVehicles: enrouteVehicles,
                            availableVehicles: availableVehicles,
                            maintenanceVehicles: maintenanceVehicles
                        )
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
                }
            }
        }
    }

    private var maintenanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                DashboardSectionTitle("Maintenance")
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(FleetPalette.warning).frame(width: 8, height: 8)
                    Text("\(maintenanceViewModel.openTasks.count) open")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(FleetPalette.textSecondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(FleetPalette.warning.opacity(0.12))
                .clipShape(Capsule())
            }
            .padding(.horizontal, 2)

            GlassPanel(hasBorder: false) {
                VStack(spacing: 0) {
                    if maintenanceViewModel.openTasks.isEmpty {
                        EmptyStateView(
                            title: "No Open Maintenance",
                            message: "All vehicles are serviced and ready.",
                            systemImage: "wrench.and.screwdriver"
                        )
                        .padding(.vertical, 20)
                    } else {
                        ForEach(Array(maintenanceViewModel.openTasks.prefix(3).enumerated()), id: \.element.id) { index, task in
                            DashboardMaintenanceRow(
                                task: task,
                                assignee: usersViewModel.personnelUser(for: task.executedBy)
                            )
                            
                            if index < min(maintenanceViewModel.openTasks.count, 3) - 1 {
                                Divider()
                                    .padding(.vertical, 12)
                            }
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
        .shadow(color: Color(hex: 0x007AFF).opacity(0.25), radius: 15, x: 0, y: 8)
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
                colors: [Color(hex: 0x007AFF), Color(hex: 0x004CE5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(24)
        .shadow(color: Color(hex: 0x007AFF).opacity(0.25), radius: 15, x: 0, y: 8)
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

struct FMSMetricWidget: View {
    let title: String
    let value: String
    let subtitle: String
    let progress: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundColor(color)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.05))
                        .frame(height: 6)
                    Capsule()
                        .fill(color)
                        .frame(width: geometry.size.width * min(max(progress, 0.05), 1.0), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FleetPalette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(FleetPalette.tertiary.opacity(0.15), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 4)
    }
}

struct FleetStatusRowContent: View {
    var title: String
    var systemImage: String
    var tint: Color
    var metrics: [(String, String, Color)]

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                IconBubble(systemImage: systemImage, tint: tint)
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(FleetPalette.textPrimary)
            }
            .frame(width: 80, alignment: .leading)
            
            Divider()
                .padding(.vertical, 4)
            
            HStack(spacing: 0) {
                ForEach(metrics, id: \.0) { metric in
                    VStack(spacing: 6) {
                        Text(metric.0.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(FleetPalette.textSecondary)
                            .lineLimit(1)
                        
                        Text(metric.1)
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
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

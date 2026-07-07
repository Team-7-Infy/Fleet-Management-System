import Combine
import SwiftUI

private enum ManagerTab: Hashable {
    case live
    case users
    case vehicles
    case trips
    case maintenance
}

enum ManagerAddSheet: Identifiable {
    case user
    case vehicle
    case trip
    case maintenanceRequest

    var id: String {
        switch self {
        case .user:
            return "user"
        case .vehicle:
            return "vehicle"
        case .trip:
            return "trip"
        case .maintenanceRequest:
            return "maintenanceRequest"
        }
    }
}

struct FleetManagerDashboardView: View {
    @StateObject private var usersViewModel: UserManagementViewModel
    @StateObject private var vehiclesViewModel: VehicleViewModel
    @StateObject private var tripsViewModel: TripManagementViewModel
    @StateObject private var maintenanceViewModel: MaintenanceViewModel
    @StateObject private var notificationViewModel: NotificationViewModel
    let services: AppServices
    let onLogout: () -> Void
    private let authService: AuthServiceProtocol

    @State private var selectedTab: ManagerTab = .live
    @State private var selectedUserSegment: ManagerUserSegment = .drivers
    @State private var addSheet: ManagerAddSheet?
    @State private var maintenanceVehicleId: UUID?
    @State private var currentUserId: UUID?
    @State private var isRefreshingAll = false
    @State private var isShowingReportsHub = false
    @State private var isShowingProfile = false
    @State private var showingNotifications = false
    @State private var lastUserNotificationMessage: String?
    @State private var lastTripNotificationMessage: String?
    @State private var lastMaintenanceNotificationMessage: String?
    @Environment(\.scenePhase) private var scenePhase

    init(services: AppServices, onLogout: @escaping () -> Void) {
        self.services = services
        self.onLogout = onLogout
        self.authService = services.authService
        _usersViewModel = StateObject(
            wrappedValue: UserManagementViewModel(
                service: services.userManagementService,
                authService: services.authService
            )
        )
        _vehiclesViewModel = StateObject(
            wrappedValue: VehicleViewModel(service: services.vehicleService)
        )
        _tripsViewModel = StateObject(
            wrappedValue: TripManagementViewModel(
                tripService: services.tripService,
                vehicleService: services.vehicleService,
                userManagementService: services.userManagementService
            )
        )
        _maintenanceViewModel = StateObject(
            wrappedValue: MaintenanceViewModel(
                maintenanceService: services.maintenanceService,
                vehicleService: services.vehicleService,
                workOrderAssignmentService: services.workOrderAssignmentService,
                notificationService: services.notificationService,
                userManagementService: services.userManagementService
            )
        )
        _notificationViewModel = StateObject(
            wrappedValue: NotificationViewModel(
                notificationService: services.notificationService,
                recipientId: nil,
                role: .manager
            )
        )
    }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                liveTab
                    .tabItem { Label("Live", systemImage: "map") }
                    .tag(ManagerTab.live)

                usersTab
                    .tabItem { Label("Users", systemImage: "person.2") }
                    .tag(ManagerTab.users)

                vehiclesTab
                    .tabItem { Label("Vehicles", systemImage: "car.2") }
                    .tag(ManagerTab.vehicles)

                tripsTab
                    .tabItem { Label("Trips", systemImage: "point.topleft.down.curvedto.point.bottomright.up") }
                    .tag(ManagerTab.trips)
                    .badge(tripsViewModel.rejectionRequests.count)

                maintenanceTab
                    .tabItem { Label("Workshop", systemImage: "wrench.and.screwdriver") }
                    .tag(ManagerTab.maintenance)
            }
            .tint(FleetPalette.accent)

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
        .task {
            currentUserId = try? await authService.currentSession()?.id
            notificationViewModel.setRecipientId(currentUserId)
            await refreshAll()
            await notificationViewModel.loadNotifications()
            notificationViewModel.subscribeToRealtime()
        }
        .onDisappear {
            notificationViewModel.unsubscribeRealtime()
        }
        .onReceive(Timer.publish(every: 20, on: .main, in: .common).autoconnect()) { _ in
            Task { await refreshAll() }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await refreshAll() }
        }
        .onChange(of: usersViewModel.successMessage) { _, message in
            guard let message,
                  message.contains(" added."),
                  message != lastUserNotificationMessage
            else {
                return
            }

            lastUserNotificationMessage = message
            notificationViewModel.addLocalNotification(
                title: "User Added",
                message: message,
                type: "user_created"
            )
        }
        .onChange(of: tripsViewModel.successMessage) { _, message in
            guard let message else { return }
            guard message != lastTripNotificationMessage else { return }
            lastTripNotificationMessage = message

            let driverId = tripsViewModel.lastTripNotificationTargetDriverId
            defer { tripsViewModel.lastTripNotificationTargetDriverId = nil }

            if message.hasPrefix("Trip created") {
                let title = message.contains("assigned to") ? "Trip Assigned" : "Trip Created"
                notificationViewModel.addLocalNotification(
                    title: title,
                    message: message,
                    type: "trip_assignment",
                    recipientIdOverride: driverId.flatMap { usersViewModel.driverUser(for: $0)?.id } ?? currentUserId
                )
            } else if message.hasPrefix("Rejection approved") {
                notificationViewModel.addLocalNotification(
                    title: "Trip Reassigned",
                    message: message,
                    type: "trip_assignment",
                    recipientIdOverride: driverId.flatMap { usersViewModel.driverUser(for: $0)?.id } ?? currentUserId
                )
            } else if message.hasPrefix("Rejection denied") {
                notificationViewModel.addLocalNotification(
                    title: "Rejection Denied",
                    message: message,
                    type: "trip_assignment",
                    recipientIdOverride: driverId.flatMap { usersViewModel.driverUser(for: $0)?.id } ?? currentUserId
                )
            }
        }
        .onChange(of: maintenanceViewModel.successMessage) { _, message in
            guard let message else { return }
            guard message != lastMaintenanceNotificationMessage else { return }
            lastMaintenanceNotificationMessage = message
            if message == "Task assigned." {
                notificationViewModel.addLocalNotification(
                    title: "Work Order Assigned",
                    message: "A maintenance task has been assigned to personnel.",
                    type: "work_order_assigned"
                )
            } else if message.hasPrefix("Task marked") {
                let status = message.replacingOccurrences(of: "Task marked ", with: "").replacingOccurrences(of: ".", with: "")
                notificationViewModel.addLocalNotification(
                    title: "Work Order \(status.capitalized)",
                    message: message,
                    type: "work_order_assigned"
                )
            }
        }
        .sheet(item: $addSheet) { sheet in
            ManagerAddSheetView(
                sheet: sheet,
                usersViewModel: usersViewModel,
                vehiclesViewModel: vehiclesViewModel,
                tripsViewModel: tripsViewModel,
                maintenanceViewModel: maintenanceViewModel,
                initialMaintenanceVehicleId: maintenanceVehicleId,
                currentUserId: currentUserId
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private var liveTab: some View {
        NavigationStack {
            ManagerOverviewView(
                usersViewModel: usersViewModel,
                vehiclesViewModel: vehiclesViewModel,
                tripsViewModel: tripsViewModel,
                maintenanceViewModel: maintenanceViewModel,
                notificationViewModel: notificationViewModel,
                showingNotifications: $showingNotifications,
                refresh: refreshAll,
                currentUserId: currentUserId,
                onProfile: { isShowingProfile = true },
                onShowReportsHub: { isShowingReportsHub = true }
            )
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isShowingProfile) {
                if let user = usersViewModel.user(for: currentUserId) {
                    ManagerProfileView(
                        services: services,
                        user: user,
                        onLogout: onLogout
                    )
                } else {
                    ProgressView("Loading Profile...")
                }
            }
            .navigationDestination(isPresented: $showingNotifications) {
                NotificationListView(viewModel: notificationViewModel)
            }
            .navigationDestination(isPresented: $isShowingReportsHub) {
                ReportsHubView(
                    tripsViewModel: tripsViewModel,
                    vehiclesViewModel: vehiclesViewModel,
                    maintenanceViewModel: maintenanceViewModel,
                    usersViewModel: usersViewModel
                )
            }
        }
    }

    private var usersTab: some View {
        NavigationStack {
            ManagerUsersView(
                viewModel: usersViewModel,
                tripsViewModel: tripsViewModel,
                maintenanceViewModel: maintenanceViewModel,
                selectedSegment: $selectedUserSegment,
                openAddUser: { addSheet = .user }
            )
            .navigationDestination(isPresented: $showingNotifications) {
                NotificationListView(viewModel: notificationViewModel)
            }
        }
    }

    private var vehiclesTab: some View {
        NavigationStack {
            ManagerVehiclesView(
                viewModel: vehiclesViewModel,
                usersViewModel: usersViewModel,
                openAddVehicle: { addSheet = .vehicle },
                openMaintenanceRequest: { vehicleId in
                    maintenanceVehicleId = vehicleId
                    addSheet = .maintenanceRequest
                }
            )
            .navigationDestination(isPresented: $showingNotifications) {
                NotificationListView(viewModel: notificationViewModel)
            }
        }
    }

    private var maintenanceTab: some View {
        NavigationStack {
            ManagerMaintenanceView(
                viewModel: maintenanceViewModel,
                vehiclesViewModel: vehiclesViewModel,
                usersViewModel: usersViewModel,
                inventoryService: services.inventoryService,
                onNotification: { title, message, type in
                    notificationViewModel.addLocalNotification(title: title, message: message, type: type)
                },
                openMaintenanceRequest: {
                    maintenanceVehicleId = nil
                    addSheet = .maintenanceRequest
                }
            )
            .navigationDestination(isPresented: $showingNotifications) {
                NotificationListView(viewModel: notificationViewModel)
            }
        }
    }

    private var tripsTab: some View {
        NavigationStack {
            ManagerTripsView(
                viewModel: tripsViewModel,
                vehiclesViewModel: vehiclesViewModel,
                usersViewModel: usersViewModel,
                openAddTrip: { addSheet = .trip }
            )
            .navigationDestination(isPresented: $showingNotifications) {
                NotificationListView(viewModel: notificationViewModel)
            }
        }
    }

    @MainActor
    private func refreshAll() async {
        guard isRefreshingAll == false else { return }
        isRefreshingAll = true
        defer { isRefreshingAll = false }

        await usersViewModel.load()
        await vehiclesViewModel.load()
        await tripsViewModel.load()
        await maintenanceViewModel.load()
        await vehiclesViewModel.loadVehicleHealthScores()
    }

}

struct ManagerAddSheetView: View {
    var sheet: ManagerAddSheet
    @ObservedObject var usersViewModel: UserManagementViewModel
    @ObservedObject var vehiclesViewModel: VehicleViewModel
    @ObservedObject var tripsViewModel: TripManagementViewModel
    @ObservedObject var maintenanceViewModel: MaintenanceViewModel
    var initialMaintenanceVehicleId: UUID?
    var currentUserId: UUID?

    var body: some View {
        NavigationStack {
            switch sheet {
            case .user:
                ManagerUserFormSheet(viewModel: usersViewModel)
            case .vehicle:
                ManagerVehicleFormSheet(viewModel: vehiclesViewModel)
            case .trip:
                ManagerTripFormSheet(viewModel: tripsViewModel)
            case .maintenanceRequest:
                ManagerMaintenanceRequestSheet(
                    viewModel: maintenanceViewModel,
                    vehiclesViewModel: vehiclesViewModel,
                    usersViewModel: usersViewModel,
                    tripsViewModel: tripsViewModel,
                    initialVehicleId: initialMaintenanceVehicleId,
                    currentUserId: currentUserId
                )
            }
        }
    }
}



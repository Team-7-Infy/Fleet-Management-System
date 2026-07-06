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
                vehicleService: services.vehicleService
            )
        )
        _maintenanceViewModel = StateObject(
            wrappedValue: MaintenanceViewModel(
                maintenanceService: services.maintenanceService,
                vehicleService: services.vehicleService
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
                    .tabItem { Label("Service", systemImage: "wrench") }
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
        .sheet(isPresented: $showingNotifications) {
            NotificationListView(viewModel: notificationViewModel)
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
        }
    }

    private var maintenanceTab: some View {
        NavigationStack {
            ManagerMaintenanceView(
                viewModel: maintenanceViewModel,
                vehiclesViewModel: vehiclesViewModel,
                usersViewModel: usersViewModel,
                inventoryService: services.inventoryService,
                openMaintenanceRequest: {
                    maintenanceVehicleId = nil
                    addSheet = .maintenanceRequest
                }
            )
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
                ManagerTripFormSheet(
                    viewModel: tripsViewModel,
                    vehiclesViewModel: vehiclesViewModel,
                    usersViewModel: usersViewModel
                )
            case .maintenanceRequest:
                ManagerMaintenanceRequestSheet(
                    viewModel: maintenanceViewModel,
                    vehiclesViewModel: vehiclesViewModel,
                    usersViewModel: usersViewModel,
                    initialVehicleId: initialMaintenanceVehicleId,
                    currentUserId: currentUserId
                )
            }
        }
    }
}



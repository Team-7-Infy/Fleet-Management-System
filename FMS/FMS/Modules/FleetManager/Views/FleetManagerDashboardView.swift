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
    @StateObject private var notificationController: ManagerNotificationController
    let onLogout: () -> Void
    private let authService: AuthServiceProtocol

    @State private var selectedTab: ManagerTab = .live
    @State private var selectedUserSegment: ManagerUserSegment = .drivers
    @State private var addSheet: ManagerAddSheet?
    @State private var maintenanceVehicleId: UUID?
    @State private var currentUserId: UUID?
    @State private var isRefreshingAll = false
    @Environment(\.scenePhase) private var scenePhase

    init(services: AppServices, onLogout: @escaping () -> Void) {
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
        _notificationController = StateObject(
            wrappedValue: ManagerNotificationController(service: services.fleetNotificationService)
        )
    }

    var body: some View {
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
        .task {
            currentUserId = try? await authService.currentSession()?.id
            await refreshAll()
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
    }

    private var liveTab: some View {
        NavigationStack {
            ManagerOverviewView(
                usersViewModel: usersViewModel,
                vehiclesViewModel: vehiclesViewModel,
                tripsViewModel: tripsViewModel,
                maintenanceViewModel: maintenanceViewModel,
                notificationController: notificationController,
                refresh: refreshAll,
                currentUserId: currentUserId,
                onLogout: onLogout
            )
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
        await notificationController.load(recipientId: currentUserId)
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

struct ManagerAccountView: View {
    var user: User?
    var onLogout: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                heroSection
                accountInfoSection
                signOutButton
            }
            .padding()
            .padding(.bottom, 24)
        }
        .fleetScreenBackground()
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.large)
    }

    private var heroSection: some View {
        VStack(spacing: 10) {
            AvatarView(name: displayName, role: .fleetManager, size: 86, imageURL: user?.avatarImageURL)

            VStack(spacing: 4) {
                Text(displayName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(FleetPalette.textPrimary)

                Text(user?.email ?? "Loading account")
                    .font(.subheadline)
                    .foregroundStyle(FleetPalette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }

    private var accountInfoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            DashboardSectionTitle("Personal Information")

            GlassPanel {
                if let user {
                    VStack(spacing: 12) {
                        InfoRow(title: "Email", value: user.email)
                        Divider()
                        InfoRow(title: "Phone", value: "\(user.contact)")
                        Divider()
                        InfoRow(title: "Role", value: user.role.title)
                        Divider()
                        InfoRow(title: "Status", value: user.isActive ? "Active" : "Inactive")
                    }
                } else {
                    EmptyStateView(
                        title: "Account loading",
                        message: "Your manager profile will appear here once the app finishes refreshing.",
                        systemImage: "person.circle"
                    )
                }
            }
        }
    }

    private var signOutButton: some View {
        Button(action: onLogout) {
            Text("Sign Out")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(FleetPalette.danger)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(FleetPalette.surface)
                        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
                )
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }

    private var displayName: String {
        guard let user else { return "Fleet Manager" }
        let name = user.displayName
        return name.isEmpty ? "Fleet Manager" : name
    }
}

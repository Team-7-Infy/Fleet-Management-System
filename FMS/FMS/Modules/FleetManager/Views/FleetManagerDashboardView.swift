import SwiftUI

private enum ManagerTab: Hashable {
    case live
    case users
    case vehicles
    case trips
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

    @State private var selectedTab: ManagerTab = .live
    @State private var selectedUserSegment: ManagerUserSegment = .drivers
    @State private var addSheet: ManagerAddSheet?
    @State private var maintenanceVehicleId: UUID?

    init(services: AppServices) {
        _usersViewModel = StateObject(
            wrappedValue: UserManagementViewModel(service: services.userManagementService)
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
        }
        .tint(FleetPalette.primary)
        .task {
            await refreshAll()
        }
        .sheet(item: $addSheet) { sheet in
            ManagerAddSheetView(
                sheet: sheet,
                usersViewModel: usersViewModel,
                vehiclesViewModel: vehiclesViewModel,
                tripsViewModel: tripsViewModel,
                maintenanceViewModel: maintenanceViewModel,
                initialMaintenanceVehicleId: maintenanceVehicleId
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
                quickAddTrip: { addSheet = .trip },
                quickMaintenance: {
                    maintenanceVehicleId = nil
                    addSheet = .maintenanceRequest
                },
                refresh: refreshAll
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await refreshAll() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh live dashboard")
                }
            }
        }
    }

    private var usersTab: some View {
        NavigationStack {
            ManagerUsersView(
                viewModel: usersViewModel,
                tripsViewModel: tripsViewModel,
                maintenanceViewModel: maintenanceViewModel,
                selectedSegment: $selectedUserSegment
            )
            .toolbar {
                ToolbarItem(placement: .principal) {
                    ManagerUserSegmentToolbar(selection: $selectedUserSegment)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    AddToolbarButton(title: "Create Credentials") {
                        addSheet = .user
                    }
                }
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    AddToolbarButton(title: "Add Vehicle") {
                        addSheet = .vehicle
                    }
                }
            }
        }
    }

    private var tripsTab: some View {
        NavigationStack {
            ManagerTripsView(
                viewModel: tripsViewModel,
                vehiclesViewModel: vehiclesViewModel,
                usersViewModel: usersViewModel
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    AddToolbarButton(title: "Create Trip") {
                        addSheet = .trip
                    }
                }
            }
        }
    }

    @MainActor
    private func refreshAll() async {
        await usersViewModel.load()
        await vehiclesViewModel.load()
        await tripsViewModel.load()
        await maintenanceViewModel.load()
    }
}

private struct ManagerUserSegmentToolbar: View {
    @Binding var selection: ManagerUserSegment

    var body: some View {
        Picker("User type", selection: $selection) {
            ForEach(ManagerUserSegment.allCases) { segment in
                Text(segment.title).tag(segment)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.large)
        .frame(width: 260, height: 44)
        .accessibilityLabel("User type")
    }
}

struct ManagerAddSheetView: View {
    var sheet: ManagerAddSheet
    @ObservedObject var usersViewModel: UserManagementViewModel
    @ObservedObject var vehiclesViewModel: VehicleViewModel
    @ObservedObject var tripsViewModel: TripManagementViewModel
    @ObservedObject var maintenanceViewModel: MaintenanceViewModel
    var initialMaintenanceVehicleId: UUID?

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
                    initialVehicleId: initialMaintenanceVehicleId
                )
            }
        }
    }
}

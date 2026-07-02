import SwiftUI

private enum ManagerVehicleFilter: String, CaseIterable, Identifiable {
    case all
    case active
    case maintenance
    case inactive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .active: return "Active"
        case .maintenance: return "Service"
        case .inactive: return "Inactive"
        }
    }

    func includes(_ vehicle: Vehicle) -> Bool {
        switch self {
        case .all:
            return true
        case .active:
            return vehicle.status == .active
        case .maintenance:
            return vehicle.status == .maintenance
        case .inactive:
            return vehicle.status == .inactive
        }
    }
}

struct ManagerVehiclesView: View {
    @ObservedObject var viewModel: VehicleViewModel
    @ObservedObject var usersViewModel: UserManagementViewModel
    @State private var searchText = ""
    @State private var filter: ManagerVehicleFilter = .all

    var openAddVehicle: () -> Void
    var openMaintenanceRequest: (UUID?) -> Void

    private var filteredVehicles: [Vehicle] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filteredByStatus = viewModel.vehicles.filter { filter.includes($0) }
        guard query.isEmpty == false else { return filteredByStatus }

        return filteredByStatus.filter { vehicle in
            [
                vehicle.licencePlate,
                vehicle.make,
                vehicle.model,
                vehicle.vehicleType,
                vehicle.status.title,
                vehicle.id.uuidString
            ]
            .contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FeedbackView(success: viewModel.successMessage, error: viewModel.errorMessage)

                if viewModel.vehicles.isEmpty {
                    ContentUnavailableView(
                        "No vehicles",
                        systemImage: "car",
                        description: Text("Add vehicle details with plate, model, VIN UUID, status, and vehicle type.")
                    )
                } else if filteredVehicles.isEmpty {
                    ContentUnavailableView.search
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredVehicles) { vehicle in
                            NavigationLink {
                                ManagerVehicleDetailView(
                                    vehicle: vehicle,
                                    viewModel: viewModel,
                                    usersViewModel: usersViewModel,
                                    openMaintenanceRequest: openMaintenanceRequest
                                )
                            } label: {
                                ManagerVehicleRow(
                                    vehicle: vehicle,
                                    driver: usersViewModel.driverUser(for: vehicle.driverId)
                                )
                            }
                            .buttonStyle(.plain)

                            if vehicle.id != filteredVehicles.last?.id {
                                Divider()
                                    .padding(.leading, 86)
                            }
                        }
                    }
                    .background(FleetPalette.surface, in: RoundedRectangle(cornerRadius: 22))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(FleetPalette.tertiary.opacity(0.45), lineWidth: 1)
                    }
                }
            }
            .padding()
        }
        .fleetScreenBackground()
        .navigationTitle("Vehicles")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search vehicles")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                VehicleFilterMenu(filter: $filter)
                Button("Add Vehicle", systemImage: "plus", action: openAddVehicle)
            }
        }
        .refreshable {
            await viewModel.load()
        }
    }
}

private struct VehicleFilterMenu: View {
    @Binding var filter: ManagerVehicleFilter

    var body: some View {
        Menu("Filter", systemImage: "line.3.horizontal.decrease.circle") {
            Picker("Vehicle status", selection: $filter) {
                ForEach(ManagerVehicleFilter.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
        }
    }
}

private struct ManagerVehicleRow: View {
    var vehicle: Vehicle
    var driver: User?

    var body: some View {
        HStack(spacing: 14) {
            VehicleAssetImage(vehicle: vehicle, width: 72, height: 56, cornerRadius: 15)

            VStack(alignment: .leading, spacing: 5) {
                Text(verbatim: vehicle.licencePlate)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(FleetPalette.textPrimary)
                    .lineLimit(1)

                Text(verbatim: modelName)
                    .font(.subheadline)
                    .foregroundStyle(FleetPalette.textSecondary)
                    .lineLimit(1)

                Text(driver.map { "Driver - \($0.displayName)" } ?? "Unassigned")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(driver == nil ? FleetPalette.textSecondary : FleetPalette.accent)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            StatusDot(text: vehicle.status.title, color: FleetPalette.vehicleStatus(vehicle.status))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FleetPalette.surface)
        .accessibilityElement(children: .combine)
    }

    private var modelName: String {
        "\(vehicle.year) \(vehicle.make) \(vehicle.model)"
    }
}

private struct ManagerVehicleDetailView: View {
    var vehicle: Vehicle
    @ObservedObject var viewModel: VehicleViewModel
    @ObservedObject var usersViewModel: UserManagementViewModel
    var openMaintenanceRequest: (UUID?) -> Void

    private var currentVehicle: Vehicle {
        viewModel.vehicle(for: vehicle.id) ?? vehicle
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                vehicleHeader
                FeedbackView(success: viewModel.successMessage, error: viewModel.errorMessage)
                vehicleDetails
                assignmentDetails
                maintenanceDetails
            }
            .padding()
        }
        .fleetScreenBackground()
        .navigationTitle("Vehicle Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                VehicleActionMenu(vehicle: currentVehicle, viewModel: viewModel)
            }
        }
    }

    private var vehicleHeader: some View {
        GlassPanel {
            HStack(alignment: .center, spacing: 16) {
                VehicleAssetImage(vehicle: currentVehicle, width: 94, height: 70, cornerRadius: 18)

                VStack(alignment: .leading, spacing: 8) {
                    Text(currentVehicle.licencePlate)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(FleetPalette.textPrimary)
                    Text("\(currentVehicle.year) \(currentVehicle.make) \(currentVehicle.model)")
                        .font(.subheadline)
                        .foregroundStyle(FleetPalette.textSecondary)
                    HStack {
                        StatusDot(text: currentVehicle.status.title, color: FleetPalette.vehicleStatus(currentVehicle.status))
                        StatusPill(text: currentVehicle.vehicleType.capitalized, color: FleetPalette.accent)
                    }
                }

                Spacer()

                VehicleHealthRing(score: VehicleHealth.score(for: currentVehicle))
            }
        }
    }

    private var vehicleDetails: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text("Fleet Details")
                    .font(.title3.bold())
                InfoRow(title: "Plate Number", value: currentVehicle.licencePlate)
                InfoRow(title: "VIN", value: currentVehicle.id.uuidString)
                InfoRow(title: "Make", value: currentVehicle.make)
                InfoRow(title: "Model", value: currentVehicle.model)
                InfoRow(title: "Year", value: "\(currentVehicle.year)")
                InfoRow(title: "Type", value: currentVehicle.vehicleType.capitalized)
                InfoRow(title: "Status", value: currentVehicle.status.title)
            }
        }
    }

    private var assignmentDetails: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text("Assignment")
                    .font(.title3.bold())

                if let driver = usersViewModel.driverUser(for: currentVehicle.driverId) {
                    InfoRow(title: "Assigned Driver", value: driver.displayName)
                    InfoRow(title: "Contact", value: "\(driver.contact)")
                    InfoRow(title: "Email", value: driver.email)
                } else {
                    EmptyStateView(
                        title: "Unassigned",
                        message: "This vehicle is available for a new trip assignment.",
                        systemImage: "person.crop.circle.badge.questionmark"
                    )
                }
            }
        }
    }

    private var maintenanceDetails: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text("Maintenance")
                    .font(.title3.bold())

                if currentVehicle.status != .maintenance {
                    Button {
                        openMaintenanceRequest(currentVehicle.id)
                    } label: {
                        Label("Send to Maintenance", systemImage: "wrench.and.screwdriver")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(FleetPalette.accent)
                } else {
                    Text("This vehicle is currently marked for maintenance.")
                        .font(.subheadline)
                        .foregroundStyle(FleetPalette.textSecondary)
                }
            }
        }
    }
}

enum VehicleHealth {
    static func score(for vehicle: Vehicle) -> Int {
        switch vehicle.status {
        case .active:
            return vehicle.driverId == nil ? 92 : 78
        case .maintenance:
            return 42
        case .inactive:
            return 24
        }
    }
}

private struct VehicleHealthRing: View {
    var score: Int

    var body: some View {
        ZStack {
            Circle()
                .stroke(FleetPalette.tertiary.opacity(0.25), lineWidth: 8)
            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(score)")
                    .font(.headline.bold())
                Text("health")
                    .font(.caption2)
                    .foregroundStyle(FleetPalette.textSecondary)
            }
        }
        .frame(width: 72, height: 72)
    }

    private var ringColor: Color {
        if score >= 80 {
            return FleetPalette.success
        }
        if score >= 60 {
            return FleetPalette.warning
        }
        return FleetPalette.danger
    }
}

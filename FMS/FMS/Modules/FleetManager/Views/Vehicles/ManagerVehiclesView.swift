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

struct ManagerVehicleDetailView: View {
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
                vehicleHeroSection
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

    private var vehicleHeroSection: some View {
        VStack(spacing: 12) {
            VehicleAssetImage(vehicle: currentVehicle, width: 140, height: 100, cornerRadius: 20)

            VStack(spacing: 6) {
                Text(currentVehicle.licencePlate)
                    .font(.title.weight(.bold))
                    .foregroundStyle(FleetPalette.textPrimary)

                Text("\(String(currentVehicle.year)) \(currentVehicle.make) \(currentVehicle.model)")
                    .font(.headline)
                    .foregroundStyle(FleetPalette.textSecondary)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 8) {
                    // Status Badge
                    Text(currentVehicle.status.title.uppercased())
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(FleetPalette.vehicleStatus(currentVehicle.status))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(FleetPalette.vehicleStatus(currentVehicle.status).opacity(0.12))
                        .clipShape(Capsule())
                    
                    // Vehicle Type Badge
                    Text(currentVehicle.vehicleType.uppercased())
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(FleetPalette.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(FleetPalette.accent.opacity(0.12))
                        .clipShape(Capsule())
                    
                    // Health Score Badge
                    let healthScore = VehicleHealth.score(for: currentVehicle)
                    let healthColor = healthScore >= 80 ? FleetPalette.success : healthScore >= 50 ? FleetPalette.warning : FleetPalette.danger
                    Text("HEALTH \(healthScore)%")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(healthColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(healthColor.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private var vehicleDetails: some View {
        VStack(alignment: .leading, spacing: 10) {
            DashboardSectionTitle("Fleet Details")
            
            GlassPanel(hasBorder: false) {
                VStack(spacing: 12) {
                    InfoRow(title: "Plate Number", value: currentVehicle.licencePlate)
                    Divider()
                    InfoRow(title: "VIN", value: formatVIN(currentVehicle.id.uuidString))
                    Divider()
                    InfoRow(title: "Make", value: currentVehicle.make)
                    Divider()
                    InfoRow(title: "Model", value: currentVehicle.model)
                    Divider()
                    InfoRow(title: "Year", value: String(currentVehicle.year))
                    Divider()
                    InfoRow(title: "Type", value: currentVehicle.vehicleType.capitalized)
                    Divider()
                    InfoRow(title: "Status", value: currentVehicle.status.title)
                }
            }
        }
    }

    private func formatVIN(_ id: String) -> String {
        let clean = id.replacingOccurrences(of: "-", with: "")
        if clean.count > 12 {
            let first = clean.prefix(8)
            let last = clean.suffix(6)
            return "\(first)...\(last)".uppercased()
        }
        return id.uppercased()
    }

    private var assignmentDetails: some View {
        VStack(alignment: .leading, spacing: 10) {
            DashboardSectionTitle("Assignment")
            
            GlassPanel(hasBorder: false) {
                if let driver = usersViewModel.driverUser(for: currentVehicle.driverId) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 14) {
                            AvatarView(name: driver.displayName, role: .driver, size: 48, imageURL: driver.avatarImageURL)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Assigned Driver")
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(FleetPalette.textSecondary)
                                Text(driver.displayName)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(FleetPalette.textPrimary)
                            }
                        }
                        
                        Divider()
                            .padding(.vertical, 4)
                        
                        InfoRow(title: "Phone", value: "\(driver.contact)")
                        Divider()
                        InfoRow(title: "Email", value: driver.email)
                    }
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
        VStack(alignment: .leading, spacing: 10) {
            DashboardSectionTitle("Maintenance")
            
            GlassPanel(hasBorder: false) {
                VStack(alignment: .leading, spacing: 12) {
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

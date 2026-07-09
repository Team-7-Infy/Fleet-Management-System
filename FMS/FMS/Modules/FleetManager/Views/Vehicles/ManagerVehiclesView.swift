import SwiftUI

private enum ManagerVehicleFilter: String, CaseIterable, Identifiable {
    case active
    case maintenance
    case inactive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .active: return "Available"
        case .maintenance: return "Maintenance"
        case .inactive: return "Out of Service"
        }
    }

    var symbolName: String {
        switch self {
        case .active: return "checkmark.circle"
        case .maintenance: return "wrench.and.screwdriver"
        case .inactive: return "pause.circle"
        }
    }

    func includes(_ vehicle: Vehicle) -> Bool {
        switch self {
        case .active:
            return vehicle.status == .available
        case .maintenance:
            return vehicle.status == .inMaintenance
        case .inactive:
            return vehicle.status == .outOfService
        }
    }
}

struct ManagerVehiclesView: View {
    @ObservedObject var viewModel: VehicleViewModel
    @ObservedObject var usersViewModel: UserManagementViewModel
    @ObservedObject var tripsViewModel: TripManagementViewModel
    @ObservedObject var maintenanceViewModel: MaintenanceViewModel
    @State private var searchText = ""
    @State private var selectedStatusFilter = "All"

    var openAddVehicle: () -> Void
    var openMaintenanceRequest: (UUID?) -> Void

    private let availableStatusFilters = ["Available", "On Trip", "Maintenance", "Out of Service"]

    private var filteredVehicles: [Vehicle] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filteredByStatus = viewModel.vehicles.filter { vehicle in
            guard selectedStatusFilter != "All" else { return true }
            let status = calculateVehicleStatus(
                vehicle: vehicle,
                trips: tripsViewModel.trips,
                tasks: maintenanceViewModel.tasks,
                taskVehicles: maintenanceViewModel.taskVehicles
            ).text
            return status.lowercased() == selectedStatusFilter.lowercased()
        }
        guard query.isEmpty == false else { return filteredByStatus }

        return filteredByStatus.filter { vehicle in
            [
                vehicle.licencePlate,
                vehicle.make,
                vehicle.model,
                vehicle.vehicleType,
                vehicle.id.uuidString
            ]
            .contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {

            if viewModel.vehicles.isEmpty {
                ContentUnavailableView(
                    "No vehicles",
                    systemImage: "car",
                    description: Text("Add vehicle details with plate, model, VIN UUID, status, and vehicle type.")
                )
            } else if filteredVehicles.isEmpty {
                ContentUnavailableView.search
            } else {
                List {
                    ForEach(filteredVehicles) { vehicle in
                        NavigationLink {
                            ManagerVehicleDetailView(
                                vehicle: vehicle,
                                viewModel: viewModel,
                                usersViewModel: usersViewModel,
                                maintenanceViewModel: maintenanceViewModel,
                                openMaintenanceRequest: openMaintenanceRequest
                            )
                        } label: {
                            ManagerVehicleRow(
                                vehicle: vehicle,
                                driver: usersViewModel.driverUser(for: vehicle.driverId),
                                mechanic: getMechanicUser(for: vehicle),
                                tripsViewModel: tripsViewModel,
                                maintenanceViewModel: maintenanceViewModel
                            )
                        }
                        .listRowBackground(FleetPalette.surface)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task { await viewModel.delete(vehicle) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                Task { await viewModel.delete(vehicle) }
                            } label: {
                                Label("Delete Vehicle", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(FleetPalette.background)
            }
        }
        .fleetScreenBackground()
        .navigationTitle("Vehicles")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search vehicles")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button {
                        selectedStatusFilter = "All"
                    } label: {
                        HStack {
                            Text("All")
                            if selectedStatusFilter == "All" {
                                Image(systemName: "checkmark")
                            }
                        }
                    }

                    ForEach(availableStatusFilters, id: \.self) { status in
                        Button {
                            selectedStatusFilter = status
                        } label: {
                            HStack {
                                Text(status)
                                if selectedStatusFilter == status {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                }
                .accessibilityLabel("Filter vehicles")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add Vehicle", systemImage: "plus", action: openAddVehicle)
            }
        }
        .refreshable {
            await tripsViewModel.load()
            await maintenanceViewModel.load()
            await viewModel.load(
                trips: tripsViewModel.trips,
                tasks: maintenanceViewModel.tasks,
                taskVehicles: maintenanceViewModel.taskVehicles
            )
        }
    }

    private func getMechanicUser(for vehicle: Vehicle) -> User? {
        let tasks = maintenanceViewModel.tasks
        let taskVehicles = maintenanceViewModel.taskVehicles
        
        let openTask = tasks.first { task in
            task.status.isOpen &&
            (taskVehicles[task.id]?.contains { $0.vin == vehicle.id } ?? false)
        }
        
        guard let openTask, let mechanicId = openTask.executedBy else { return nil }
        return usersViewModel.personnelUser(for: mechanicId)
    }
}

private struct ManagerVehicleRow: View {
    var vehicle: Vehicle
    var driver: User?
    var mechanic: User?
    @ObservedObject var tripsViewModel: TripManagementViewModel
    @ObservedObject var maintenanceViewModel: MaintenanceViewModel

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VehicleAssetImage(vehicle: vehicle, width: 74, height: 58, cornerRadius: 14)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center) {
                    Text(vehicle.licencePlate)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(FleetPalette.textPrimary)
                }

                Text(modelName)
                    .font(.subheadline)
                    .foregroundStyle(FleetPalette.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 5) {
                    Image(systemName: "person.fill")
                        .font(.caption)
                    Text(subtextValue)
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(subtextColor)
                .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var modelName: String {
        "\(vehicle.make) \(vehicle.model)"
    }

    private var subtextValue: String {
        let status = calculateVehicleStatus(
            vehicle: vehicle,
            trips: tripsViewModel.trips,
            tasks: maintenanceViewModel.tasks,
            taskVehicles: maintenanceViewModel.taskVehicles
        ).text

        if status == "Maintenance" {
            return mechanic.map { "Mechanic: \($0.displayName)" } ?? "Under Maintenance"
        } else {
            return driver.map { $0.displayName } ?? "Unassigned"
        }
    }

    private var subtextColor: Color {
        let status = calculateVehicleStatus(
            vehicle: vehicle,
            trips: tripsViewModel.trips,
            tasks: maintenanceViewModel.tasks,
            taskVehicles: maintenanceViewModel.taskVehicles
        ).text

        if status == "Maintenance" {
            return FleetPalette.warning
        } else if status == "On Trip" {
            return FleetPalette.accent
        } else {
            return FleetPalette.textTertiary
        }
    }
}

struct ManagerVehicleDetailView: View {
    var vehicle: Vehicle
    @ObservedObject var viewModel: VehicleViewModel
    @ObservedObject var usersViewModel: UserManagementViewModel
    @ObservedObject var maintenanceViewModel: MaintenanceViewModel
    var openMaintenanceRequest: (UUID?) -> Void

    @State private var showEditSheet = false

    private var currentVehicle: Vehicle {
        viewModel.vehicle(for: vehicle.id) ?? vehicle
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                vehicleHeroSection
                FeedbackView(success: viewModel.successMessage, error: viewModel.errorMessage)
                vehicleDetails
                complianceDocsSection
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
                VehicleActionMenu(
                    vehicle: currentVehicle,
                    viewModel: viewModel,
                    onEdit: { showEditSheet = true }
                )
            }
        }
        .sheet(isPresented: $showEditSheet) {
            NavigationStack {
                ManagerVehicleFormSheet(
                    viewModel: viewModel,
                    existingVehicle: currentVehicle
                )
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
                    StatusPill(
                        text: currentVehicle.status.title,
                        color: FleetPalette.vehicleStatus(currentVehicle.status),
                        dotSize: 8
                    )

                    Text(currentVehicle.vehicleType.uppercased())
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(FleetPalette.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(FleetPalette.accent.opacity(0.12))
                        .clipShape(Capsule())

                    let healthScore = viewModel.vehicleHealthScores.first { $0.vehicle.id == currentVehicle.id }?.score ?? VehicleHealth.score(for: currentVehicle)
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
                    InfoRow(title: "Vehicle Age", value: currentVehicle.currentAgeString)
                    Divider()
                    InfoRow(title: "Type", value: currentVehicle.vehicleType.capitalized)
                    Divider()
                    InfoRow(title: "Fuel Type", value: currentVehicle.fuelType?.capitalized ?? "N/A")
                    Divider()
                    if let liters = currentVehicle.fuelCapacityLiters {
                        InfoRow(title: "Fuel Capacity", value: "\(Int(liters)) L")
                        Divider()
                    } else if let kwh = currentVehicle.batteryCapacityKwh {
                        InfoRow(title: "Battery Capacity", value: "\(Int(kwh)) kWh")
                        Divider()
                    }
                    InfoRow(title: "Status", value: currentVehicle.status.title)
                    if currentVehicle.status == .inMaintenance {
                        let linkedTaskIds = maintenanceViewModel.taskVehicles
                            .flatMap { _, vehicles in vehicles }
                            .filter { $0.vin == currentVehicle.id }
                            .map { $0.taskId }
                        if let activeTask = maintenanceViewModel.tasks.first(where: { linkedTaskIds.contains($0.id) && $0.status != .completed }) {
                            let assignee = usersViewModel.personnelUser(for: activeTask.executedBy)
                            Divider()
                            InfoRow(title: "Maintenance", value: activeTask.displayTitle)
                            Divider()
                            InfoRow(title: "Assigned To", value: assignee?.displayName ?? "Unassigned")
                        }
                    }
                    if let kmInterval = currentVehicle.maintenanceKmInterval {
                        Divider()
                        InfoRow(title: "Service Every", value: "\(kmInterval) km")
                    }
                    if let monthInterval = currentVehicle.maintenanceMonthInterval {
                        Divider()
                        InfoRow(title: "Service Every", value: "\(monthInterval) months")
                    }
                }
            }
        }
    }

    private var complianceDocsSection: some View {
        VehicleComplianceDocsView(
            viewModel: viewModel,
            vehicleId: currentVehicle.id
        )
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
                    if currentVehicle.status != .inMaintenance {
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
        case .available:
            return vehicle.driverId == nil ? 92 : 78
        case .assigned:
            return 78
        case .inMaintenance:
            return 42
        case .outOfService:
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

// MARK: - Vehicle Status Calculation Helper
func calculateVehicleStatus(
    vehicle: Vehicle,
    trips: [Trip],
    tasks: [MaintenanceTask],
    taskVehicles: [UUID: [TaskVehicle]]
) -> (text: String, color: Color) {
    if vehicle.status == .outOfService {
        return ("Out of Service", FleetPalette.neutral)
    }

    // Check if Maintenance
    let isLinkedToOpenTask = tasks.contains { task in
        task.status.isOpen &&
        (taskVehicles[task.id]?.contains { $0.vin == vehicle.id } ?? false)
    }
    if vehicle.status == .inMaintenance || isLinkedToOpenTask {
        return ("Maintenance", FleetPalette.warning)
    }

    // Check if On Trip (only active live trip)
    let vehicleTrips = trips.filter { $0.vehicleId == vehicle.id }
    let hasActiveTrip = vehicleTrips.contains { $0.status == .accepted || $0.status == .inProgress }
    if hasActiveTrip {
        return ("On Trip", FleetPalette.accent)
    }

    return ("Available", FleetPalette.success)
}

import SwiftUI

struct ManagerVehiclesView: View {
    @ObservedObject var viewModel: VehicleViewModel
    @ObservedObject var usersViewModel: UserManagementViewModel
    @State private var searchText = ""

    var openAddVehicle: () -> Void
    var openMaintenanceRequest: (UUID?) -> Void

    private var filteredVehicles: [Vehicle] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else { return viewModel.vehicles }

        return viewModel.vehicles.filter { vehicle in
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
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ScreenHeader(title: "Vehicles")
                    FleetSearchBar(text: $searchText)

                    FeedbackView(success: viewModel.successMessage, error: viewModel.errorMessage)

                    if viewModel.vehicles.isEmpty {
                        GlassPanel {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Fleet Register")
                                    .font(.title3.bold())
                                EmptyStateView(
                                    title: "No vehicles",
                                    message: "Add vehicle details with plate, model, VIN UUID, status, and vehicle type.",
                                    systemImage: "car"
                                )
                            }
                        }
                    } else if filteredVehicles.isEmpty {
                        GlassPanel {
                            EmptyStateView(
                                title: "No matching vehicles",
                                message: "Try a different plate number, model, type, VIN, or status.",
                                systemImage: "magnifyingglass"
                            )
                        }
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
                        .background(FleetPalette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(FleetPalette.tertiary.opacity(0.45), lineWidth: 1)
                        }
                    }
                }
                .padding()
            }
            .fleetScreenBackground()
            .refreshable {
                await viewModel.load()
            }

            Button(action: openAddVehicle) {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(FleetPalette.primary, in: Circle())
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 16)
        }
    }
}

private struct ManagerVehicleRow: View {
    var vehicle: Vehicle
    var driver: User?

    var body: some View {
        HStack(spacing: 14) {
            IconBubble(systemImage: vehicleSymbol, tint: FleetPalette.primary)

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
                    .foregroundStyle(driver == nil ? FleetPalette.textSecondary : FleetPalette.primary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            StatusPill(text: vehicle.status.title, color: FleetPalette.vehicleStatus(vehicle.status))
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

    private var vehicleSymbol: String {
        let type = vehicle.vehicleType.lowercased()
        if type.contains("bus") {
            return "bus.fill"
        }
        if type.contains("truck") {
            return "box.truck.fill"
        }
        if type.contains("van") {
            return "car.side.fill"
        }
        return "car.fill"
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
                VStack(alignment: .leading, spacing: 8) {
                    Text(currentVehicle.licencePlate)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(FleetPalette.textPrimary)
                    Text("\(currentVehicle.year) \(currentVehicle.make) \(currentVehicle.model)")
                        .font(.subheadline)
                        .foregroundStyle(FleetPalette.textSecondary)
                    HStack {
                        StatusPill(text: currentVehicle.status.title, color: FleetPalette.vehicleStatus(currentVehicle.status))
                        StatusPill(text: currentVehicle.vehicleType.capitalized, color: FleetPalette.primary)
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
                    .tint(FleetPalette.primary)
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

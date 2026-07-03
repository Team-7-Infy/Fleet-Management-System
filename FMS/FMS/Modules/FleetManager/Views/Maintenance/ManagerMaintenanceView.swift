import SwiftUI

private enum ManagerServiceFilter: String, CaseIterable, Identifiable {
    case type
    case assigned
    case inProgress
    case completed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .type: return "Type"
        case .assigned: return "Assigned"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        }
    }

    func includes(_ task: MaintenanceTask) -> Bool {
        switch self {
        case .type:
            return true
        case .assigned:
            return task.status == .assigned
        case .inProgress:
            return task.status == .inProgress
        case .completed:
            return task.status == .completed
        }
    }
}

struct ManagerMaintenanceView: View {
    @ObservedObject var viewModel: MaintenanceViewModel
    @ObservedObject var vehiclesViewModel: VehicleViewModel
    @ObservedObject var usersViewModel: UserManagementViewModel
    var inventoryService: InventoryServiceProtocol
    @State private var filter: ManagerServiceFilter = .type
    var openMaintenanceRequest: () -> Void

    private var filteredTasks: [MaintenanceTask] {
        viewModel.tasks
            .filter { filter.includes($0) }
            .sorted {
                if $0.isUrgent != $1.isUrgent {
                    return $0.isUrgent && !$1.isUrgent
                }
                return $0.reportedOrScheduledDate > $1.reportedOrScheduledDate
            }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Workshop")
                        .font(.largeTitle.weight(.heavy))
                        .foregroundStyle(FleetPalette.textPrimary)

                    Spacer()

                    NavigationLink("View Inventory") {
                        ManagerInventoryView(inventoryService: inventoryService)
                    }
                    .font(.subheadline.weight(.semibold))
                }

                if viewModel.tasks.isEmpty {
                    GlassPanel(hasBorder: false) {
                        ContentUnavailableView(
                            "No work orders",
                            systemImage: "doc.text.magnifyingglass",
                            description: Text("Request maintenance and assign registered personnel.")
                        )
                    }
                } else if filteredTasks.isEmpty {
                    GlassPanel(hasBorder: false) {
                        ContentUnavailableView(
                            "No matching work orders",
                            systemImage: "line.3.horizontal.decrease",
                            description: Text("Change the service filter to see more work orders.")
                        )
                    }
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(filteredTasks) { task in
                            NavigationLink {
                                ManagerServiceDetailView(
                                    task: task,
                                    viewModel: viewModel,
                                    vehiclesViewModel: vehiclesViewModel,
                                    usersViewModel: usersViewModel
                                )
                            } label: {
                                ManagerWorkOrderCard(
                                    task: task,
                                    viewModel: viewModel,
                                    vehiclesViewModel: vehiclesViewModel
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
        }
        .fleetScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                ServiceFilterMenu(filter: $filter)
                Button("Request Maintenance", systemImage: "plus", action: openMaintenanceRequest)
            }
        }
        .refreshable {
            await viewModel.load()
            await vehiclesViewModel.load()
            await usersViewModel.load()
        }
    }
}

private struct ServiceFilterMenu: View {
    @Binding var filter: ManagerServiceFilter

    var body: some View {
        Menu("Filter", systemImage: "line.3.horizontal.decrease") {
            Picker("Service status", selection: $filter) {
                ForEach(ManagerServiceFilter.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
        }
    }
}

private struct ManagerWorkOrderCard: View {
    var task: MaintenanceTask
    @ObservedObject var viewModel: MaintenanceViewModel
    @ObservedObject var vehiclesViewModel: VehicleViewModel

    private var vehicle: Vehicle? {
        guard let vin = viewModel.vehicles(for: task).first?.vin else { return nil }
        return vehiclesViewModel.vehicle(for: vin)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(task.displayTitle)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(FleetPalette.textPrimary)
                        .lineLimit(2)

                    if let vehicle {
                        Text(vehicle.licencePlate)
                            .font(.subheadline)
                            .foregroundStyle(FleetPalette.textSecondary)
                            .lineLimit(1)
                    } else {
                        Text("No Vehicle Linked")
                            .font(.subheadline)
                            .foregroundStyle(FleetPalette.textTertiary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 8) {
                    StatusPill(
                        text: task.status.title,
                        color: FleetPalette.maintenanceStatus(task.status),
                        dotSize: 8
                    )

                    if task.isUrgent {
                        UrgentTag()
                    }
                }
            }

            Divider()
                .background(FleetPalette.tertiary.opacity(0.5))

            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "calendar")
                        .font(.caption)
                    Text("Reported \(task.hoursAgoText)")
                        .font(.caption)
                }
                .foregroundStyle(FleetPalette.textSecondary)
                
                Spacer()
                
                if let cost = task.totalCost, cost > 0 {
                    Text("Cost: ₹\(Int(cost))")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(FleetPalette.success)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(FleetPalette.surface)
                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
        )
    }
}

private struct UrgentTag: View {
    var body: some View {
        Text("URGENT")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(FleetPalette.danger)
            .clipShape(Capsule())
            .accessibilityLabel("Urgent")
    }
}

private struct ManagerInventoryView: View {
    var inventoryService: InventoryServiceProtocol
    @State private var parts: [InventoryPart] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if isLoading && parts.isEmpty {
                    ProgressView("Loading inventory...")
                        .frame(maxWidth: .infinity, minHeight: 220)
                } else if let errorMessage {
                    ContentUnavailableView(
                        "Inventory unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                    .frame(maxWidth: .infinity, minHeight: 220)
                } else if parts.isEmpty {
                    ContentUnavailableView(
                        "No inventory",
                        systemImage: "shippingbox",
                        description: Text("Inventory table has no parts yet.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 220)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(parts) { part in
                            InventoryPartRow(part: part)
                        }
                    }
                }
            }
            .padding()
        }
        .fleetScreenBackground()
        .navigationTitle("Inventory")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadParts()
        }
        .refreshable {
            await loadParts()
        }
    }

    private func loadParts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            parts = try await inventoryService.fetchParts()
                .sorted { $0.partName.localizedCaseInsensitiveCompare($1.partName) == .orderedAscending }
            errorMessage = nil
        } catch is CancellationError {
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct InventoryPartRow: View {
    var part: InventoryPart

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(part.partName)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(FleetPalette.textPrimary)
                        .lineLimit(2)

                    Text(part.vehicleType.capitalized)
                        .font(.subheadline)
                        .foregroundStyle(FleetPalette.textSecondary)
                }

                Spacer(minLength: 12)

                Text("Qty \(part.quantity)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(part.quantity > 5 ? FleetPalette.success : FleetPalette.warning)
            }

            Divider()
                .background(FleetPalette.tertiary.opacity(0.5))

            HStack {
                Text("Part ID")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FleetPalette.textSecondary)
                Spacer()
                Text(part.id.uuidString.prefix(8).uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FleetPalette.textPrimary)
            }

            HStack {
                Text("Cost")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FleetPalette.textSecondary)
                Spacer()
                Text("₹\(Int(part.cost))")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(FleetPalette.textPrimary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(FleetPalette.surface)
                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
        )
    }
}

private struct ManagerServiceDetailView: View {
    var task: MaintenanceTask
    @ObservedObject var viewModel: MaintenanceViewModel
    @ObservedObject var vehiclesViewModel: VehicleViewModel
    @ObservedObject var usersViewModel: UserManagementViewModel

    private var currentTask: MaintenanceTask {
        viewModel.tasks.first { $0.id == task.id } ?? task
    }

    private var assignee: User? {
        usersViewModel.personnelUser(for: currentTask.executedBy)
    }

    private var reporter: User? {
        guard let scheduledBy = currentTask.scheduledBy,
              let manager = usersViewModel.fleetManagers.first(where: { $0.id == scheduledBy })
        else {
            return nil
        }
        return usersViewModel.user(for: manager.userId)
    }

    private var vehicle: Vehicle? {
        guard let vehicleId = viewModel.vehicles(for: currentTask).first?.vin else { return nil }
        return vehiclesViewModel.vehicle(for: vehicleId)
    }

    private var partsUsedText: String {
        if let summary = currentTask.partsSummary?.trimmingCharacters(in: .whitespacesAndNewlines),
           summary.isEmpty == false {
            return summary
        }

        let parts = viewModel.parts(for: currentTask)
        guard parts.isEmpty == false else { return "Not recorded" }
        let quantity = parts.reduce(0) { $0 + $1.quantityUsed }
        return "\(quantity) part\(quantity == 1 ? "" : "s") recorded"
    }

    private var timeTakenText: String {
        if let hours = currentTask.timeTakenHours {
            return "\(hours.formatted(.number.precision(.fractionLength(1)))) hr"
        }

        guard let completedAt = currentTask.completedAt else { return "Not recorded" }
        let minutes = max(0, Calendar.current.dateComponents([.minute], from: currentTask.reportedOrScheduledDate, to: completedAt).minute ?? 0)
        return minutes < 60 ? "\(minutes) min" : "\((Double(minutes) / 60).formatted(.number.precision(.fractionLength(1)))) hr"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                GlassPanel {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(currentTask.displayTitle)
                                    .font(.title2.bold())
                                    .foregroundStyle(FleetPalette.textPrimary)
                                Text(currentTask.description)
                                    .font(.subheadline)
                                    .foregroundStyle(FleetPalette.textSecondary)
                            }
                            Spacer()
                            StatusDot(text: currentTask.status.title, color: FleetPalette.maintenanceStatus(currentTask.status))
                        }

                        if currentTask.isUrgent {
                            StatusPill(text: "Urgent", color: FleetPalette.danger)
                        }
                    }
                }

                serviceDetails

                if currentTask.status == .completed {
                    completedDetails
                }
            }
            .padding()
        }
        .fleetScreenBackground()
        .navigationTitle(currentTask.status == .completed ? "Completed Service" : "Service Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var serviceDetails: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text("Service Details")
                    .font(.title3.bold())
                InfoRow(title: "Vehicle", value: vehicle.map { "\($0.licencePlate) - \($0.make) \($0.model)" } ?? "Not linked")
                InfoRow(title: "Assigned to", value: assignee?.displayName ?? "Unassigned")
                InfoRow(title: "Reported by", value: reporter?.displayName ?? "System")
                InfoRow(title: "Reported date", value: FleetManagerFormat.shortDateTime.string(from: currentTask.reportedOrScheduledDate))
                InfoRow(title: "Scheduled date", value: FleetManagerFormat.day.string(from: currentTask.scheduledDate.date))
                photosSection
            }
        }
    }

    private var completedDetails: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text("Completed")
                    .font(.title3.bold())
                InfoRow(title: "Time taken", value: timeTakenText)
                InfoRow(title: "Parts used", value: partsUsedText)
                InfoRow(title: "Cost", value: currentTask.formattedCost)
            }
        }
    }

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Photos")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(FleetPalette.textSecondary)

            let urls = currentTask.photoUrls ?? []
            if urls.isEmpty {
                Text("No photos attached")
                    .font(.subheadline)
                    .foregroundStyle(FleetPalette.textPrimary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(urls, id: \.self) { urlString in
                            AsyncImage(url: URL(string: urlString)) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                default:
                                    Image(systemName: "photo")
                                        .font(.title2)
                                        .foregroundStyle(FleetPalette.textSecondary)
                                }
                            }
                            .frame(width: 96, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .background(FleetPalette.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
            }
        }
    }
}

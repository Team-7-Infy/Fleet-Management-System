import SwiftUI

private enum MaintenanceSegment: String, CaseIterable, Identifiable {
    case active = "Active"
    case history = "History"
    
    var id: String { rawValue }
}

struct ManagerMaintenanceView: View {
    @ObservedObject var viewModel: MaintenanceViewModel
    @ObservedObject var vehiclesViewModel: VehicleViewModel
    @ObservedObject var usersViewModel: UserManagementViewModel
    var inventoryService: InventoryServiceProtocol
    @State private var selectedSegment: MaintenanceSegment = .active
    @State private var searchText = ""
    var openMaintenanceRequest: () -> Void

    private var filteredTasks: [MaintenanceTask] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = viewModel.tasks
            .filter { task in
                switch selectedSegment {
                case .active:
                    return task.status != .completed
                case .history:
                    return task.status == .completed
                }
            }
            .filter { task in
                guard query.isEmpty == false else { return true }
                let vehicle = viewModel.vehicles(for: task).first.flatMap { tv in
                    vehiclesViewModel.vehicle(for: tv.vin)
                }
                let searchable = [
                    task.displayTitle,
                    task.description,
                    task.status.title,
                    vehicle?.licencePlate,
                    vehicle.map { "\($0.make) \($0.model)" }
                ]
                return searchable.compactMap { $0 }.contains { $0.localizedCaseInsensitiveContains(query) }
            }
        return filtered.sorted {
            if $0.isUrgent != $1.isUrgent {
                return $0.isUrgent && !$1.isUrgent
            }
            return $0.reportedOrScheduledDate > $1.reportedOrScheduledDate
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FeedbackView(success: viewModel.successMessage, error: viewModel.errorMessage)

                if viewModel.tasks.isEmpty {
                    ContentUnavailableView(
                        "No work orders",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Request maintenance and assign registered personnel.")
                    )
                } else if filteredTasks.isEmpty {
                    ContentUnavailableView.search
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
        .navigationTitle("Workshop")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search tasks")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu("Filter", systemImage: "line.3.horizontal.decrease") {
                    Picker("Service Status", selection: $selectedSegment) {
                        ForEach(MaintenanceSegment.allCases) { segment in
                            Text(segment.rawValue).tag(segment)
                        }
                    }
                }
                NavigationLink {
                    ManagerInventoryView(inventoryService: inventoryService)
                } label: {
                    Image(systemName: "shippingbox")
                }
                Button("Request Workshop", systemImage: "plus", action: openMaintenanceRequest)
            }
        }
        .task {
            await viewModel.load()
            await vehiclesViewModel.load()
            await usersViewModel.load()
        }
        .refreshable {
            await viewModel.load()
            await vehiclesViewModel.load()
            await usersViewModel.load()
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

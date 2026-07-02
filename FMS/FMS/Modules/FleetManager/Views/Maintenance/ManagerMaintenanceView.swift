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
                GlassPanel {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Work Orders")
                            .font(.title3.bold())
                        if viewModel.tasks.isEmpty {
                            ContentUnavailableView(
                                "No work orders",
                                systemImage: "doc.text.magnifyingglass",
                                description: Text("Request maintenance and assign registered personnel.")
                            )
                        } else if filteredTasks.isEmpty {
                            ContentUnavailableView(
                                "No matching work orders",
                                systemImage: "line.3.horizontal.decrease.circle",
                                description: Text("Change the service filter to see more work orders.")
                            )
                        } else {
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
                                        assignee: usersViewModel.personnelUser(for: task.executedBy),
                                        viewModel: viewModel,
                                        usersViewModel: usersViewModel
                                    )
                                }
                                .buttonStyle(.plain)

                                if task.id != filteredTasks.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .fleetScreenBackground()
        .navigationTitle("Service")
        .navigationBarTitleDisplayMode(.large)
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
        Menu("Filter", systemImage: "line.3.horizontal.decrease.circle") {
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
    var assignee: User?
    @ObservedObject var viewModel: MaintenanceViewModel
    @ObservedObject var usersViewModel: UserManagementViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(task.displayTitle)
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
                StatusDot(text: task.status.title, color: FleetPalette.maintenanceStatus(task.status))
                MaintenanceActionMenu(
                    task: task,
                    personnel: usersViewModel.maintenancePersonnel,
                    usersViewModel: usersViewModel,
                    viewModel: viewModel
                )
            }
            InfoRow(title: "Reported", value: task.hoursAgoText)
            InfoRow(title: "Assigned To", value: assignee?.displayName ?? "Unassigned")
            InfoRow(title: "Urgent", value: task.isUrgent ? "Yes" : "No")
        }
        .padding(.vertical, 6)
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

import SwiftUI

struct ManagerMaintenanceView: View {
    @ObservedObject var viewModel: MaintenanceViewModel
    @ObservedObject var vehiclesViewModel: VehicleViewModel
    @ObservedObject var usersViewModel: UserManagementViewModel
    var openMaintenanceRequest: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScreenHeader(title: "Service")

                GlassPanel {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Vehicles In Maintenance")
                                .font(.title3.bold())
                            Spacer()
                            Button(action: openMaintenanceRequest) {
                                Image(systemName: "plus")
                            }
                            .accessibilityLabel("Request maintenance")
                        }

                        if vehiclesViewModel.maintenanceVehicles.isEmpty {
                            EmptyStateView(
                                title: "No immediate service due",
                                message: "Vehicles marked for maintenance will be shown here.",
                                systemImage: "checkmark.seal"
                            )
                        } else {
                            ForEach(vehiclesViewModel.maintenanceVehicles) { vehicle in
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(vehicle.licencePlate)
                                            .font(.headline)
                                        Text("\(vehicle.year) \(vehicle.make) \(vehicle.model)")
                                            .foregroundStyle(FleetPalette.textSecondary)
                                    }
                                    Spacer()
                                    StatusPill(text: vehicle.status.title, color: FleetPalette.warning)
                                }

                                if vehicle.id != vehiclesViewModel.maintenanceVehicles.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }

                GlassPanel {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Work Orders")
                            .font(.title3.bold())
                        if viewModel.tasks.isEmpty {
                            EmptyStateView(
                                title: "No work orders",
                                message: "Request maintenance and assign registered personnel.",
                                systemImage: "doc.text.magnifyingglass"
                            )
                        } else {
                            ForEach(viewModel.tasks) { task in
                                ManagerWorkOrderRow(
                                    task: task,
                                    assignee: usersViewModel.personnelUser(for: task.executedBy),
                                    viewModel: viewModel,
                                    usersViewModel: usersViewModel
                                )

                                if task.id != viewModel.tasks.last?.id {
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
        .refreshable {
            await viewModel.load()
            await vehiclesViewModel.load()
            await usersViewModel.load()
        }
    }
}

private struct ManagerWorkOrderRow: View {
    var task: MaintenanceTask
    var assignee: User?
    @ObservedObject var viewModel: MaintenanceViewModel
    @ObservedObject var usersViewModel: UserManagementViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(task.description)
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
                StatusPill(text: task.status.title, color: FleetPalette.maintenanceStatus(task.status))
                MaintenanceActionMenu(
                    task: task,
                    personnel: usersViewModel.maintenancePersonnel,
                    usersViewModel: usersViewModel,
                    viewModel: viewModel
                )
            }
            InfoRow(title: "Assigned To", value: assignee?.displayName ?? "Unassigned")
            InfoRow(title: "Scheduled", value: FleetManagerFormat.day.string(from: task.scheduledDate.date))
            InfoRow(title: "Urgent", value: task.isUrgent ? "Yes" : "No")
        }
    }
}

//
//  ManagerMaintenanceRequestSheet.swift
//  FMS
//
//  Created by Veer on 26/06/26.
//


import SwiftUI

struct ManagerMaintenanceRequestSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MaintenanceViewModel
    @ObservedObject var vehiclesViewModel: VehicleViewModel
    @ObservedObject var usersViewModel: UserManagementViewModel
    @State private var form = FleetManagerMaintenanceTaskForm()
    var initialVehicleId: UUID?
    var currentUserId: UUID?

    private var hasRegisteredPersonnel: Bool {
        usersViewModel.maintenancePersonnel.contains { $0.status == .active }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if vehiclesViewModel.vehicles.isEmpty || hasRegisteredPersonnel == false {
                    GlassPanel {
                        EmptyStateView(
                            title: "Maintenance setup needs data",
                            message: "Add a vehicle and register at least one maintenance person before assigning work orders.",
                            systemImage: "wrench.and.screwdriver"
                        )
                    }
                } else {
                    Picker("Vehicle", selection: $form.vehicleId) {
                        Text("Select vehicle").tag(Optional<UUID>.none)
                        ForEach(vehiclesViewModel.vehicles) { vehicle in
                            Text(vehicle.licencePlate).tag(Optional(vehicle.id))
                        }
                    }
                    .fleetField()

                    TextField("Reason", text: $form.description, axis: .vertical)
                        .lineLimit(2...4)
                        .fleetField()

                    DatePicker("Scheduled date", selection: $form.scheduledDate, displayedComponents: .date)
                        .fleetField()

                    Toggle("Urgent", isOn: $form.isUrgent)
                        .fleetField()

                    Picker("Assign To", selection: $form.executedBy) {
                        Text("Unassigned").tag(Optional<UUID>.none)
                        ForEach(usersViewModel.maintenancePersonnel) { person in
                            let user = usersViewModel.user(for: person.userId)
                            Text(user?.displayName ?? person.id.uuidString)
                                .tag(Optional(person.id))
                        }
                    }
                    .fleetField()

                    FeedbackView(success: viewModel.successMessage, error: viewModel.errorMessage)

                    Button {
                        Task {
                            if form.executedBy != nil && form.status == .scheduled {
                                form.status = .assigned
                            }

                            if await viewModel.createTask(form: form) {
                                await vehiclesViewModel.load()
                                dismiss()
                            }
                        }
                    } label: {
                        Label("Assign Maintenance", systemImage: "wrench.and.screwdriver")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(FleetPalette.primary)
                    .disabled(form.isValid == false || form.vehicleId == nil)
                }
            }
            .padding()
        }
        .fleetScreenBackground()
        .navigationTitle("Request Maintenance")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            form.vehicleId = form.vehicleId ?? initialVehicleId ?? vehiclesViewModel.vehicles.first?.id
            form.executedBy = form.executedBy ?? usersViewModel.maintenancePersonnel.first(where: { $0.status == .active })?.id
            form.description = form.description.isEmpty ? "Preventive maintenance" : form.description
            form.scheduledBy = form.scheduledBy ?? currentUserId.flatMap(usersViewModel.managerId(for:))
        }
    }
}
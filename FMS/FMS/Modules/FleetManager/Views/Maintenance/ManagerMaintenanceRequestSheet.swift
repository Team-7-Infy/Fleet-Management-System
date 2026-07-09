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
    @ObservedObject var tripsViewModel: TripManagementViewModel
    @State private var form = FleetManagerMaintenanceTaskForm()
    var initialVehicleId: UUID?
    var currentUserId: UUID?

    private var hasRegisteredPersonnel: Bool {
        !usersViewModel.maintenancePersonnel.isEmpty
    }

    private var availableVehicles: [Vehicle] {
        var list = vehiclesViewModel.vehicles.filter { $0.status == .available }
        list = list.filter { vehicle in
            let isAssignedToActiveTrip = tripsViewModel.activeTrips.contains { $0.vehicleId == vehicle.id }
            return !isAssignedToActiveTrip
        }
        return list
    }

    private var availablePersonnel: [MaintenancePersonnel] {
        usersViewModel.maintenancePersonnel.filter { person in
            person.status == .available
        }
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
                        ForEach(availableVehicles) { vehicle in
                            Text(vehicle.licencePlate).tag(Optional(vehicle.id))
                        }
                    }
                    .fleetField()

                    TextField("Title", text: $form.title)
                        .fleetField()

                    TextField("Description", text: $form.description, axis: .vertical)
                        .lineLimit(2...4)
                        .fleetField()

                    DatePicker("Scheduled date", selection: $form.scheduledDate, in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date)
                        .fleetField()

                    Toggle("Urgent", isOn: $form.isUrgent)
                        .fleetField()

                    Toggle("Auto Assign", isOn: $form.isAutoAssign)
                        .fleetField()

                    if !form.isAutoAssign {
                        Picker("Assign To", selection: $form.executedBy) {
                            Text("Unassigned").tag(Optional<UUID>.none)
                            ForEach(availablePersonnel) { person in
                                let user = usersViewModel.user(for: person.userId)
                                Text(user?.displayName ?? person.id.uuidString)
                                    .tag(Optional(person.id))
                            }
                        }
                        .fleetField()
                    }



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
                    .tint(FleetPalette.accent)
                    .disabled(form.isValid == false || form.vehicleId == nil)
                }
            }
            .padding()
        }
        .fleetScreenBackground()
        .navigationTitle("Request Maintenance")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            form.vehicleId = form.vehicleId ?? initialVehicleId ?? availableVehicles.first?.id
            form.title = form.title.isEmpty ? "Engine oil and filter change" : form.title
            form.description = form.description.isEmpty ? "Replace engine oil, oil filter, and inspect for leakage before the next trip." : form.description
            form.scheduledBy = form.scheduledBy ?? currentUserId.flatMap(usersViewModel.managerId(for:))

            Task {
                if let leastLoadedId = await viewModel.getNextLeastLoadedAssigneeId() {
                    form.executedBy = form.executedBy ?? leastLoadedId
                }
            }
        }
    }
}

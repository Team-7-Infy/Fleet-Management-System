//
//  ManagerTripFormSheet.swift
//  FMS
//
//  Created by Veer on 26/06/26.
//


import SwiftUI

struct ManagerTripFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TripManagementViewModel
    @ObservedObject var vehiclesViewModel: VehicleViewModel
    @ObservedObject var usersViewModel: UserManagementViewModel
    @State private var form = FleetManagerTripForm()
    @State private var minimumStartTime = Date()

    private var hasRegisteredDriver: Bool {
        usersViewModel.drivers.contains { $0.status == .active }
    }

    private var availableDrivers: [Driver] {
        usersViewModel.drivers.filter { $0.status == .active }
    }

    private var availableVehicles: [Vehicle] {
        vehiclesViewModel.vehicles.filter { $0.status == .active }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if vehiclesViewModel.vehicles.isEmpty || hasRegisteredDriver == false {
                    GlassPanel {
                        EmptyStateView(
                            title: "Trip setup needs fleet data",
                            message: "Add at least one active vehicle and one active driver before creating trips.",
                            systemImage: "point.topleft.down.curvedto.point.bottomright.up"
                        )
                    }
                } else {
                    TextField("Starting point", text: $form.startLocation)
                        .textInputAutocapitalization(.words)
                        .fleetField()

                    TextField("Destination", text: $form.endLocation)
                        .textInputAutocapitalization(.words)
                        .fleetField()

                    Picker("Vehicle", selection: $form.vehicleId) {
                        Text("Select vehicle").tag(Optional<UUID>.none)
                        ForEach(availableVehicles) { vehicle in
                            Text("\(vehicle.licencePlate) - \(vehicle.make) \(vehicle.model)")
                                .tag(Optional(vehicle.id))
                        }
                    }
                    .fleetField()

                    Picker("Driver", selection: $form.driverId) {
                        Text("Select driver").tag(Optional<UUID>.none)
                        ForEach(availableDrivers) { driver in
                            let user = usersViewModel.user(for: driver.userId)
                            Text(user?.displayName ?? driver.licenceNum)
                                .tag(Optional(driver.id))
                        }
                    }
                    .fleetField()

                    DatePicker("Start", selection: $form.startTime, in: minimumStartTime...)
                        .fleetField()

                    DatePicker(
                        "Expected End",
                        selection: Binding(
                            get: { form.endTime ?? form.startTime.addingTimeInterval(3600) },
                            set: { form.endTime = $0 }
                        ),
                        in: form.startTime...
                    )
                    .fleetField()

                    FeedbackView(success: viewModel.successMessage, error: viewModel.errorMessage)

                    Button {
                        Task {
                            if await viewModel.createTrip(form: form) {
                                await vehiclesViewModel.load()
                                dismiss()
                            }
                        }
                    } label: {
                        Label("Create Trip", systemImage: "wand.and.stars")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(FleetPalette.primary)
                    .disabled(form.isValid == false)
                }
            }
            .padding()
        }
        .fleetScreenBackground()
        .navigationTitle("Create Trip")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            minimumStartTime = Date()
            if form.startTime < minimumStartTime {
                form.startTime = minimumStartTime
            }
            if let endTime = form.endTime, endTime < form.startTime {
                form.endTime = form.startTime.addingTimeInterval(3600)
            }
            form.vehicleId = form.vehicleId ?? availableVehicles.first?.id
            form.driverId = form.driverId ?? availableDrivers.first?.id
        }
        .onChange(of: form.startTime) { _, newValue in
            if newValue < minimumStartTime {
                form.startTime = minimumStartTime
            }
            if (form.endTime ?? newValue) < newValue {
                form.endTime = newValue.addingTimeInterval(3600)
            }
        }
    }
}

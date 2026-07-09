import SwiftUI

struct ManagerVehicleFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: VehicleViewModel
    var existingVehicle: Vehicle?

    @State private var form: FleetManagerVehicleForm
    @State private var editMode = false

    init(viewModel: VehicleViewModel, existingVehicle: Vehicle? = nil) {
        self.viewModel = viewModel
        self.existingVehicle = existingVehicle
        if let vehicle = existingVehicle {
            _form = State(initialValue: FleetManagerVehicleForm.form(from: vehicle))
        } else {
            _form = State(initialValue: FleetManagerVehicleForm())
        }
        _editMode = State(initialValue: existingVehicle != nil)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                FleetFormSection(title: "Identification") {
                    FleetFormRow(icon: "lanyardcard.fill", title: "Plate Number") {
                        TextField("e.g. DL 01 AB 1234", text: $form.licencePlate)
                            .textInputAutocapitalization(.characters)
                            .keyboardType(.asciiCapable)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: form.licencePlate) { _, newValue in
                                form.licencePlate = FleetManagerVehicleForm.sanitizedLicencePlateInput(newValue)
                            }
                    }
                    if let msg = visiblePlateValidationMessage {
                        FleetFormValidationRow(message: msg)
                    }
                    Divider().padding(.leading, 44)
                    
                    FleetFormRow(icon: "barcode.viewfinder", title: "VIN UUID") {
                        TextField("Optional", text: $form.vin)
                            .textInputAutocapitalization(.never)
                            .multilineTextAlignment(.trailing)
                            .disabled(editMode)
                    }
                    if let msg = form.vinValidationMessage {
                        FleetFormValidationRow(message: msg)
                    }
                }
                
                FleetFormSection(title: "Make & Model") {
                    FleetFormRow(icon: "car.fill", title: "Make") {
                        TextField("e.g. Tata", text: $form.make)
                            .multilineTextAlignment(.trailing)
                    }
                    Divider().padding(.leading, 44)
                    
                    FleetFormRow(icon: "car.side.fill", title: "Model") {
                        TextField("e.g. Ace", text: $form.model)
                            .multilineTextAlignment(.trailing)
                    }
                    Divider().padding(.leading, 44)
                    
                    FleetFormRow(icon: "calendar", title: "Year") {
                        TextField("e.g. 2022", text: $form.year)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: form.year) { _, newValue in
                                form.year = String(newValue.filter(\.isNumber).prefix(4))
                            }
                    }
                    if let msg = visibleYearValidationMessage {
                        FleetFormValidationRow(message: msg)
                    }
                    Divider().padding(.leading, 44)
                    
                    FleetFormRow(icon: "tag.fill", title: "Vehicle Type") {
                        Picker("Type", selection: $form.vehicleType) {
                            ForEach(["car", "van", "bus", "truck"], id: \.self) { type in
                                Text(type.capitalized).tag(type)
                            }
                        }
                        .tint(FleetPalette.accent)
                        .labelsHidden()
                    }
                    Divider().padding(.leading, 44)
                    
                    FleetFormRow(icon: "clock.fill", title: "Age (Years)") {
                        TextField("e.g. 2", text: $form.age)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: form.age) { _, newValue in
                                form.age = String(newValue.filter(\.isNumber).prefix(2))
                            }
                    }
                }
                
                FleetFormSection(title: "Configuration & Status") {
                    FleetFormRow(icon: "fuelpump.fill", title: "Fuel Type") {
                        Picker("Fuel", selection: $form.fuelType) {
                            Text("None").tag("")
                            ForEach(["petrol", "diesel", "cng", "electric"], id: \.self) { type in
                                Text(type.capitalized).tag(type)
                            }
                        }
                        .tint(FleetPalette.accent)
                        .labelsHidden()
                    }
                    
                    if form.fuelType == "electric" {
                        Divider().padding(.leading, 44)
                        FleetFormRow(icon: "bolt.batteryblock.fill", title: "Battery (kWh)") {
                            TextField("e.g. 40", text: $form.batteryCapacityKwh)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    } else if !form.fuelType.isEmpty {
                        Divider().padding(.leading, 44)
                        FleetFormRow(icon: "drop.fill", title: "Capacity (L)") {
                            TextField("e.g. 50", text: $form.fuelCapacityLiters)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    Divider().padding(.leading, 44)
                    
                    FleetFormRow(icon: "shield.checkered", title: "Status") {
                        Picker("Status", selection: $form.status) {
                            ForEach(editMode ? VehicleStatus.allCases : [.available, .outOfService]) { status in
                                Text(status.title).tag(status)
                            }
                        }
                        .tint(FleetPalette.accent)
                        .labelsHidden()
                    }
                }
                .animation(.easeInOut, value: form.fuelType)
                
                FleetFormSection(title: "Maintenance Intervals") {
                    FleetFormRow(icon: "gauge.with.dots.needle.bottom.100percent", title: "KM Interval") {
                        TextField("e.g. 10000", text: $form.maintenanceKmInterval)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: form.maintenanceKmInterval) { _, newValue in
                                form.maintenanceKmInterval = String(newValue.filter(\.isNumber).prefix(7))
                            }
                    }
                    Divider().padding(.leading, 44)
                    
                    FleetFormRow(icon: "calendar.badge.clock", title: "Month Interval") {
                        TextField("e.g. 6", text: $form.maintenanceMonthInterval)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: form.maintenanceMonthInterval) { _, newValue in
                                form.maintenanceMonthInterval = String(newValue.filter(\.isNumber).prefix(3))
                            }
                    }
                }

                FeedbackView(success: viewModel.successMessage, error: viewModel.errorMessage)
                
                Button {
                    Task {
                        if editMode, let vehicle = existingVehicle {
                            if await viewModel.updateVehicle(vehicle, form: form) { dismiss() }
                        } else {
                            if await viewModel.createVehicle(form: form) { dismiss() }
                        }
                    }
                } label: {
                    Label(editMode ? "Save Changes" : "Add Vehicle", systemImage: editMode ? "checkmark.circle" : "plus.circle")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(FleetPalette.accent)
                .disabled(form.isValid == false)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .padding()
        }
        .fleetScreenBackground()
        .navigationTitle(editMode ? "Edit Vehicle" : "Add Vehicle")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.successMessage = nil
            viewModel.errorMessage = nil
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
                .tint(FleetPalette.textPrimary)
            }
        }
    }

    private var visiblePlateValidationMessage: String? {
        form.normalizedLicencePlate.isEmpty ? nil : form.licencePlateValidationMessage
    }

    private var visibleYearValidationMessage: String? {
        form.year.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : form.yearValidationMessage
    }
}

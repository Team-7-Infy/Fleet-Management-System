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
            VStack(alignment: .leading, spacing: 16) {
                plateField
                vinField
                makeModelRow
                yearTypeRow
                FleetFieldValidationMessage(message: visibleYearValidationMessage)
                fuelPicker
                statusPicker
                maintenanceFields
                FeedbackView(success: viewModel.successMessage, error: viewModel.errorMessage)
                submitButton
            }
            .padding()
        }
        .fleetScreenBackground()
        .navigationTitle(editMode ? "Edit Vehicle" : "Add Vehicle")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: form.licencePlate) { _, newValue in
            form.licencePlate = FleetManagerVehicleForm.sanitizedLicencePlateInput(newValue)
        }
        .onChange(of: form.year) { _, newValue in
            form.year = String(newValue.filter(\.isNumber).prefix(4))
        }
        .onChange(of: form.maintenanceKmInterval) { _, newValue in
            form.maintenanceKmInterval = String(newValue.filter(\.isNumber).prefix(7))
        }
        .onChange(of: form.maintenanceMonthInterval) { _, newValue in
            form.maintenanceMonthInterval = String(newValue.filter(\.isNumber).prefix(3))
        }
    }

    private var plateField: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Plate number", text: $form.licencePlate)
                .textInputAutocapitalization(.characters)
                .keyboardType(.asciiCapable)
                .fleetField()
            FleetFieldValidationMessage(message: visiblePlateValidationMessage)
        }
    }

    private var vinField: some View {
        TextField("VIN UUID (optional)", text: $form.vin)
            .textInputAutocapitalization(.never)
            .fleetField()
            .disabled(editMode)
    }

    private var makeModelRow: some View {
        HStack {
            TextField("Make", text: $form.make).fleetField()
            TextField("Model", text: $form.model).fleetField()
        }
    }

    private var yearTypeRow: some View {
        HStack(alignment: .bottom) {
            TextField("Year", text: $form.year)
                .keyboardType(.numberPad)
                .fleetField()
            vehicleTypePicker
        }
    }

    private var vehicleTypePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            FleetFormFieldLabel("Vehicle Type")
            Picker(selection: $form.vehicleType) {
                ForEach(["car", "van", "bus", "truck"], id: \.self) { type in
                    Text(type.capitalized).tag(type)
                }
            } label: {
                HStack(spacing: 10) {
                    Text(form.vehicleType.capitalized)
                        .font(.body).foregroundStyle(FleetPalette.accent).lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.bold)).foregroundStyle(FleetPalette.accent)
                }
                .contentShape(Rectangle())
            }
            .pickerStyle(.menu)
            .tint(FleetPalette.accent)
            .fleetField()
        }
    }

    private var fuelPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            FleetFormFieldLabel("Fuel Type")
            Picker(selection: $form.fuelType) {
                Text("None").tag("")
                ForEach(["petrol", "diesel", "cng"], id: \.self) { type in
                    Text(type.capitalized).tag(type)
                }
            } label: {
                HStack(spacing: 10) {
                    Text(form.fuelType.isEmpty ? "None" : form.fuelType.capitalized)
                        .font(.body).foregroundStyle(FleetPalette.accent).lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.bold)).foregroundStyle(FleetPalette.accent)
                }
                .contentShape(Rectangle())
            }
            .pickerStyle(.menu)
            .tint(FleetPalette.accent)
            .fleetField()
        }
    }

    private var statusPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            FleetFormFieldLabel("Status")
            Picker(selection: $form.status) {
                ForEach(VehicleStatus.allCases) { status in
                    Text(status.title).tag(status)
                }
            } label: {
                HStack(spacing: 10) {
                    Text(form.status.title)
                        .font(.body).foregroundStyle(FleetPalette.accent).lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.bold)).foregroundStyle(FleetPalette.accent)
                }
                .contentShape(Rectangle())
            }
            .pickerStyle(.menu)
            .tint(FleetPalette.accent)
        }
    }

    private var maintenanceFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            FleetFormFieldLabel("Maintenance Intervals (optional)")
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("KM Interval").font(.caption).foregroundStyle(FleetPalette.textSecondary)
                    TextField("e.g. 10000", text: $form.maintenanceKmInterval)
                        .keyboardType(.numberPad).fleetField()
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Month Interval").font(.caption).foregroundStyle(FleetPalette.textSecondary)
                    TextField("e.g. 6", text: $form.maintenanceMonthInterval)
                        .keyboardType(.numberPad).fleetField()
                }
            }
        }
    }

    private var submitButton: some View {
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
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(FleetPalette.accent)
        .disabled(form.isValid == false)
    }

    private var visiblePlateValidationMessage: String? {
        form.normalizedLicencePlate.isEmpty ? nil : form.licencePlateValidationMessage
    }

    private var visibleYearValidationMessage: String? {
        form.year.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : form.yearValidationMessage
    }
}

//
//  ManagerVehicleFormSheet.swift
//  FMS
//
//  Created by Veer on 26/06/26.
//


import SwiftUI

struct ManagerVehicleFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: VehicleViewModel
    @State private var form = FleetManagerVehicleForm()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TextField("Plate number", text: $form.licencePlate)
                    .textInputAutocapitalization(.characters)
                    .keyboardType(.asciiCapable)
                    .fleetField()
                FleetFieldValidationMessage(message: visiblePlateValidationMessage)

                TextField("VIN UUID (optional)", text: $form.vin)
                    .textInputAutocapitalization(.never)
                    .fleetField()

                HStack {
                    TextField("Make", text: $form.make)
                        .fleetField()
                    TextField("Model", text: $form.model)
                        .fleetField()
                }

                HStack(alignment: .bottom) {
                    TextField("Year", text: $form.year)
                        .keyboardType(.numberPad)
                        .fleetField()

                    VStack(alignment: .leading, spacing: 8) {
                        FleetFormFieldLabel("Vehicle Type")

                        Picker(selection: $form.vehicleType) {
                            ForEach(["car", "van", "bus", "truck"], id: \.self) { type in
                                Text(type.capitalized).tag(type)
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Text(form.vehicleType.capitalized)
                                    .font(.body)
                                    .foregroundStyle(FleetPalette.accent)
                                    .lineLimit(1)

                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(FleetPalette.accent)
                            }
                            .contentShape(Rectangle())
                        }
                        .pickerStyle(.menu)
                        .tint(FleetPalette.accent)
                        .fleetField()
                    }
                }
                FleetFieldValidationMessage(message: visibleYearValidationMessage)

                VStack(alignment: .leading, spacing: 8) {
                    FleetFormFieldLabel("Status")

                    Picker(selection: $form.status) {
                        ForEach(VehicleStatus.allCases) { status in
                            Text(status.title).tag(status)
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Text(form.status.title)
                                .font(.body)
                                .foregroundStyle(FleetPalette.accent)
                                .lineLimit(1)

                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(FleetPalette.accent)
                        }
                        .contentShape(Rectangle())
                    }
                    .pickerStyle(.menu)
                    .tint(FleetPalette.accent)
                }

                FeedbackView(success: viewModel.successMessage, error: viewModel.errorMessage)

                Button {
                    Task {
                        if await viewModel.createVehicle(form: form) {
                            dismiss()
                        }
                    }
                } label: {
                    Label("Add Vehicle", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(FleetPalette.accent)
                .disabled(form.isValid == false)
            }
            .padding()
        }
        .fleetScreenBackground()
        .navigationTitle("Add Vehicle")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: form.licencePlate) { _, newValue in
            form.licencePlate = FleetManagerVehicleForm.sanitizedLicencePlateInput(newValue)
        }
        .onChange(of: form.year) { _, newValue in
            form.year = String(newValue.filter(\.isNumber).prefix(4))
        }
    }

    private var visiblePlateValidationMessage: String? {
        form.normalizedLicencePlate.isEmpty ? nil : form.licencePlateValidationMessage
    }

    private var visibleYearValidationMessage: String? {
        form.year.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : form.yearValidationMessage
    }
}

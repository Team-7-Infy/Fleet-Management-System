//
//  FuelRequestView.swift
//  FMSD
//
//  Created by Dev Jain on 24/06/26.
//


import SwiftUI

struct FuelRequestView: View {
    @EnvironmentObject var localStore: LocalDataStore
    @Environment(\.dismiss) var dismiss

    let assignedVehicle: String
    var hasActiveTrip: Bool = false

    init(assignedVehicle: String = "") {
        self.assignedVehicle = assignedVehicle
    }

    @State private var selectedFuelType: FuelRecord.FuelType = .diesel
    @State private var requestedAmount: String = ""
    @State private var currentFuelLevel: Double = 0.2
    @State private var isSubmitting: Bool = false
    @State private var showSuccessAlert: Bool = false

    // EV-specific fields
    @State private var kWhAdded: String = ""
    @State private var chargeBefore: Double = 0.2
    @State private var chargeAfter: Double = 0.8

    private var isLiquidFuel: Bool {
        selectedFuelType != .electric
    }

    var body: some View {
        NavigationStack {
            Form {
                if !hasActiveTrip {
                    Section {
                        VStack(spacing: 8) {
                            HStack {
                                Spacer()
                                Image(systemName: "lock.fill")
                                Text("Fuel Request Locked")
                                    .fontWeight(.bold)
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .background(Color.orange.opacity(0.15))
                            .foregroundColor(.orange)
                            .cornerRadius(10)
                            Text("Fuel can only be requested during an active trip.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }

                Section(header: Text("Vehicle Details")) {
                    HStack {
                        Text("Assigned Vehicle")
                            .foregroundColor(.gray)
                        Spacer()
                        Text(assignedVehicle)
                            .fontWeight(.bold)
                    }
                }

                Section(header: Text("Fuel Request Details")) {
                    Picker("Fuel Type", selection: $selectedFuelType) {
                        ForEach(FuelRecord.FuelType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }

                    if isLiquidFuel {
                        HStack {
                            Text("Requested Amount (₹)")
                            Spacer()
                            TextField("e.g. 150", text: $requestedAmount)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .accessibilityLabel("Requested Amount (₹)")
                        }
                    } else {
                        HStack {
                            Text("kWh Added")
                            Spacer()
                            TextField("e.g. 50", text: $kWhAdded)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }

                if isLiquidFuel {
                    Section(header: Text("Current Fuel Level (\(Int(currentFuelLevel * 100))%)")) {
                        VStack {
                            Slider(value: $currentFuelLevel, in: 0...1, step: 0.05)
                                .accentColor(fuelColor)
                                .accessibilityLabel("Current Fuel Level Slider")
                                .accessibilityValue("\(Int(currentFuelLevel * 100)) percent")

                            HStack {
                                Text("Empty").font(.caption).foregroundColor(.gray)
                                Spacer()
                                Text("Half").font(.caption).foregroundColor(.gray)
                                Spacer()
                                Text("Full").font(.caption).foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                } else {
                    Section(header: Text("Charge Level")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Before Charging")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Slider(value: $chargeBefore, in: 0...1, step: 0.05)
                                .accentColor(.green)
                            Text("\(Int(chargeBefore * 100))%")
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(.green)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("After Charging")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Slider(value: $chargeAfter, in: 0...1, step: 0.05)
                                .accentColor(.green)
                            Text("\(Int(chargeAfter * 100))%")
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(.green)
                        }
                    }
                }

                Section {
                    Button(action: submitForm) {
                        HStack {
                            Spacer()
                            if isSubmitting {
                                ProgressView().padding(.trailing, 5)
                            }
                            Text(isSubmitting ? "Sending Request..." : "Submit Request")
                                .fontWeight(.bold)
                            Spacer()
                        }
                    }
                    .foregroundColor(isFormValid ? .blue : .gray)
                    .disabled(!isFormValid || isSubmitting)
                    .accessibilityLabel("Submit Fuel Request")
                }
            }
            .navigationTitle("Request Fuel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert(isPresented: $showSuccessAlert) {
                Alert(
                    title: Text("Request Sent"),
                    message: Text("Your fuel request has been sent to the Fleet Manager for approval."),
                    dismissButton: .default(Text("OK")) {
                        dismiss()
                    }
                )
            }
        }
    }

    private var isFormValid: Bool {
        guard hasActiveTrip else { return false }
        if isLiquidFuel {
            return !requestedAmount.isEmpty
        } else {
            return !kWhAdded.isEmpty
        }
    }

    private func submitForm() {
        isSubmitting = true
        if isLiquidFuel, let amount = Double(requestedAmount) {
            localStore.submitFuelRequest(vehicleId: assignedVehicle, fuelType: selectedFuelType, amount: amount, currentLevel: currentFuelLevel)
        } else if let kWh = Double(kWhAdded) {
            localStore.submitFuelRequest(
                vehicleId: assignedVehicle,
                fuelType: selectedFuelType,
                amount: kWh * 8.0,
                currentLevel: chargeAfter
            )
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isSubmitting = false
            showSuccessAlert = true
        }
    }

    private var fuelColor: Color {
        if currentFuelLevel < 0.2 { return .red }
        if currentFuelLevel < 0.5 { return .orange }
        return .green
    }
}

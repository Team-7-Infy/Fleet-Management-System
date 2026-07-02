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

    @State private var selectedFuelType: FuelRecord.FuelType = .diesel
    @State private var requestedAmount: String = ""
    @State private var currentFuelLevel: Double = 0.2
    @State private var isSubmitting: Bool = false
    @State private var showSuccessAlert: Bool = false

    init(assignedVehicle: String = "") {
        self.assignedVehicle = assignedVehicle
    }

    var body: some View {
        NavigationStack {
            Form {
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

                    HStack {
                        Text("Requested Amount (₹)")
                        Spacer()
                        TextField("e.g. 150", text: $requestedAmount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityLabel("Requested Amount (₹)")
                    }
                }

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

                Section {
                    Button(action: {
                        if let amount = Double(requestedAmount) {
                            isSubmitting = true
                            localStore.submitFuelRequest(vehicleId: assignedVehicle, fuelType: selectedFuelType, amount: amount, currentLevel: currentFuelLevel)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                isSubmitting = false
                                showSuccessAlert = true
                            }
                        }
                    }) {
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
                    .foregroundColor(requestedAmount.isEmpty ? .gray : .blue)
                    .disabled(requestedAmount.isEmpty || isSubmitting)
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

    private var fuelColor: Color {
        if currentFuelLevel < 0.2 { return .red }
        if currentFuelLevel < 0.5 { return .orange }
        return .green
    }
}

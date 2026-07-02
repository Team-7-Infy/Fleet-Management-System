//
//  FuelRequestView.swift
//  FMSD
//
//  Created by Dev Jain on 24/06/26.
//


import SwiftUI

struct FuelRequestView: View {
    @StateObject private var viewModel = FuelViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedFuelType: FuelRecord.FuelType = .diesel
    @State private var requestedAmount: String = ""
    @State private var currentFuelLevel: Double = 0.2 // Defaults to 20%
    
    // Hardcoded for demo, normally fetched from driver session
    let assignedVehicle = "KA-01-HC-1234" 
    
    var body: some View {
        NavigationView {
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
                        Text("Requested Amount ($)")
                        Spacer()
                        TextField("e.g. 150", text: $requestedAmount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section(header: Text("Current Fuel Level (\(Int(currentFuelLevel * 100))%)")) {
                    VStack {
                        Slider(value: $currentFuelLevel, in: 0...1, step: 0.05)
                            .accentColor(fuelColor)
                        
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
                            viewModel.submitFuelRequest(vehicleId: assignedVehicle, fuelType: selectedFuelType, amount: amount, currentLevel: currentFuelLevel)
                        }
                    }) {
                        HStack {
                            Spacer()
                            if viewModel.isSubmitting {
                                ProgressView().padding(.trailing, 5)
                            }
                            Text(viewModel.isSubmitting ? "Sending Request..." : "Submit Request")
                                .fontWeight(.bold)
                            Spacer()
                        }
                    }
                    .foregroundColor(requestedAmount.isEmpty ? .gray : FleetPalette.inProgress)
                    .disabled(requestedAmount.isEmpty || viewModel.isSubmitting)
                }
            }
            .navigationTitle("Request Fuel")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
            .alert(isPresented: $viewModel.showSuccessAlert) {
                Alert(
                    title: Text("Request Sent"),
                    message: Text("Your fuel request has been sent to the Fleet Manager for approval."),
                    dismissButton: .default(Text("OK")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
        }
    }
    
    // Dynamic color based on fuel level
    private var fuelColor: Color {
        if currentFuelLevel < 0.2 { return FleetPalette.danger }
        if currentFuelLevel < 0.5 { return FleetPalette.warning }
        return FleetPalette.success
    }
}

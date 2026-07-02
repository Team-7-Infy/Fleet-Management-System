//
//  TripCompletionFormView.swift
//  FMSD
//


import SwiftUI

struct TripCompletionFormView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var localStore: LocalDataStore

    let activeTripId: String?
    let trip: Trip
    var onComplete: (_ finalOdometer: String, _ finalFuelLevel: String, _ needsMaintenance: Bool, _ driverNote: String) -> Void

    @State private var finalOdometer: String = ""
    @State private var finalFuelLevel: Double = 75.0
    @State private var needsMaintenance: Bool = false
    @State private var reportIssue: Bool = false
    @State private var selectedIncidentType: Incident.IncidentType = .other
    @State private var incidentDescription: String = ""
    @State private var driverNote: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("TRIP DETAILS")) {
                    HStack {
                        Text("Trip ID")
                        Spacer()
                        Text(trip.id.uuidString)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Vehicle")
                        Spacer()
                        Text(trip.vehicleId.uuidString)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("TRANSIT INPUTS (REQUIRED)")) {
                    HStack {
                        Text("Final Odometer")
                        Spacer()
                        TextField("Enter Odometer (km)", text: $finalOdometer)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 180)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Final Fuel Level")
                            Spacer()
                            Text("\(Int(finalFuelLevel))%")
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }

                        Slider(value: $finalFuelLevel, in: 0...100, step: 1.0)
                            .tint(.blue)
                    }
                    .padding(.vertical, 4)
                }

                Section(header: Text("VEHICLE STATUS")) {
                    Toggle(isOn: $needsMaintenance) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Car requires maintenance?")
                                .font(.body)
                            Text("Select this if you notice engine issues, tire wear, or service needs.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .tint(.blue)
                }

                Section(header: Text("REPORT A TRANSIT ISSUE")) {
                    Toggle(isOn: $reportIssue) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Report a Safety / Vehicle Issue?")
                                .font(.body)
                            Text("Logs an incident report in the dispatcher database.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .tint(.red)

                    if reportIssue {
                        Picker("Issue Type", selection: $selectedIncidentType) {
                            ForEach(Incident.IncidentType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Issue Description")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextEditor(text: $incidentDescription)
                                .frame(height: 80)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                )
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section(header: Text("TRIP NOTES / REMARKS")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Add final trip remarks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $driverNote)
                            .frame(height: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Button(action: submitCompletion) {
                        Text("Confirm & End Journey")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .listRowBackground(
                        isFormValid ? Color.blue : Color.gray.opacity(0.5)
                    )
                    .disabled(!isFormValid)
                }
            }
            .navigationTitle("Journey Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var isFormValid: Bool {
        !finalOdometer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submitCompletion() {
        HapticManager.shared.triggerNotification(type: .success)

        if reportIssue && !incidentDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            localStore.submitIncident(
                type: selectedIncidentType,
                description: incidentDescription,
                photos: [],
                latitude: nil,
                longitude: nil,
                tripId: trip.id.uuidString
            )
        }

        onComplete(finalOdometer, "\(Int(finalFuelLevel))%", needsMaintenance, driverNote)

        dismiss()
    }
}

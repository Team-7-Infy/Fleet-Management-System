import SwiftUI

struct EndTripView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var localStore: LocalDataStore

    let trip: Trip
    let services: AppServices
    var onComplete: ((_ finalOdometer: String, _ notes: String) -> Void)? = nil

    @State private var endOdometer: String = ""
    @State private var endFuel: Double = 50.0
    @State private var needsMaintenance: Bool = false
    @State private var maintenanceTitle: String = ""
    @State private var maintenanceDescription: String = ""
    @State private var isSubmitting: Bool = false
    @State private var previousOdometer: Double = 0.0

    private var isFormValid: Bool {
        let baseValid = !endOdometer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard let odoVal = Double(endOdometer), odoVal >= previousOdometer else { return false }
        if needsMaintenance {
            return baseValid &&
                   !maintenanceTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   !maintenanceDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return baseValid
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }

            VStack(spacing: 0) {
                // Gradient Header
                VStack(spacing: 16) {
                    ZStack {
                        Text("Post-Trip Inspection")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        HStack {
                            Spacer()
                            Button(action: {
                                dismiss()
                            }) {
                                textClose
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 44)
                    
                    HStack(spacing: 12) {
                        Image(systemName: "shield.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Post-Trip Safety Inspection")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Text("Trip ID: \(trip.id.shortIdentifier)")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.85))
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.0, green: 0.5, blue: 1.0), Color(red: 0.05, green: 0.15, blue: 0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea(edges: .top)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // 1. Odometer Readings Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "speedometer")
                                    .foregroundColor(.blue)
                                    .font(.headline)
                                Text("ODOMETER READING")
                                    .font(.system(size: 11, weight: .black))
                                    .foregroundColor(.secondary)
                                    .tracking(1.0)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Final Odometer *")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                HStack(spacing: 6) {
                                    TextField("Enter ending odometer (km)", text: $endOdometer)
                                        .keyboardType(.numberPad)
                                        .font(.subheadline)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                    Text("km")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                if let val = Double(endOdometer), val < previousOdometer {
                                    Text("Odometer must be at least \(Int(previousOdometer)) km")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .padding(.top, 2)
                                }
                            }
                        }
                        .padding(20)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.02), radius: 8, y: 4)

                        // 2. Fuel Level Readings Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "fuelpump.fill")
                                    .foregroundColor(.blue)
                                    .font(.headline)
                                Text("FUEL LEVEL")
                                    .font(.system(size: 11, weight: .black))
                                    .foregroundColor(.secondary)
                                    .tracking(1.0)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Final Fuel Level")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text("\(Int(endFuel))%")
                                        .font(.subheadline.monospacedDigit())
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                }
                                
                                Slider(value: $endFuel, in: 0...100, step: 1)
                                    .accentColor(.blue)
                            }
                        }
                        .padding(20)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.02), radius: 8, y: 4)

                        // 3. Maintenance Toggle Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "wrench.and.screwdriver.fill")
                                    .foregroundColor(.blue)
                                    .font(.headline)
                                Text("MAINTENANCE STATUS")
                                    .font(.system(size: 11, weight: .black))
                                    .foregroundColor(.secondary)
                                    .tracking(1.0)
                            }
                            
                            Toggle(isOn: $needsMaintenance.animation()) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Needs Maintenance")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    Text("Flag vehicle for technical inspection")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .tint(.orange)
                            
                            if needsMaintenance {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Maintenance Title *")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    TextField("e.g. Brake noise, Flat tire", text: $maintenanceTitle)
                                        .font(.subheadline)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Maintenance Description *")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    TextField("Describe the issue in detail", text: $maintenanceDescription)
                                        .font(.subheadline)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .padding(20)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.02), radius: 8, y: 4)

                        // Action Button
                        Button(action: submitTrip) {
                            HStack {
                                Spacer()
                                if isSubmitting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .padding(.trailing, 8)
                                }
                                Text(isSubmitting ? "Saving & Syncing..." : "Confirm & End Journey")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                Spacer()
                            }
                            .foregroundColor(.white)
                            .frame(height: 54)
                            .background(isFormValid ? Color.blue : Color.gray.opacity(0.4))
                            .cornerRadius(18)
                            .shadow(color: isFormValid ? Color.blue.opacity(0.15) : Color.clear, radius: 6, y: 3)
                        }
                        .disabled(!isFormValid || isSubmitting)
                        .padding(.top, 10)
                        .padding(.bottom, 30)
                    }
                    .padding(20)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if let vehicleId = trip.vehicleId,
               let vehicle = try? await services.vehicleService.fetchVehicle(id: vehicleId) {
                previousOdometer = vehicle.odometer ?? 0.0
            }
        }
    }

    private var textClose: some View {
        Text("Close")
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.85))
            .clipShape(Capsule())
    }

    private func submitTrip() {
        isSubmitting = true
        HapticManager.shared.triggerNotification(type: .success)
        
        Task {
            do {
                var updatedTrip = trip
                let odoDouble = Double(endOdometer) ?? 0.0
                updatedTrip.finalOdometer = odoDouble
                updatedTrip.finalFuelLevel = endFuel
                updatedTrip.status = .completed
                updatedTrip.endTime = Date()
                
                let note = needsMaintenance ? "Needs Maintenance" : "Post-trip check completed normally."
                updatedTrip.driverNote = note
                
                _ = try await services.tripService.updateTrip(updatedTrip)
                UserDefaults.standard.removeObject(forKey: "trip_\(trip.id.uuidString)_paused")
                
                // Update vehicle odometer and status in DB
                if let vehicleId = trip.vehicleId {
                    var vehicle = try await services.vehicleService.fetchVehicle(id: vehicleId)
                    vehicle.odometer = odoDouble
                    if needsMaintenance {
                        vehicle.status = .inMaintenance
                    }
                    _ = try await services.vehicleService.updateVehicle(vehicle)

                    if needsMaintenance {
                        let maintenanceTask = MaintenanceTask(
                            id: UUID(),
                            title: maintenanceTitle,
                            description: maintenanceDescription,
                            scheduledDate: DateOnly(wrappedValue: Date()),
                            isUrgent: true,
                            scheduledBy: nil,
                            executedBy: nil,
                            status: .scheduled,
                            reportedDate: nil,
                            completedAt: nil,
                            timeTakenHours: nil,
                            partsSummary: nil,
                            totalCost: nil,
                            photoUrls: nil,
                            elapsedTime: 0
                        )
                        
                        _ = try await services.maintenanceService.createTask(maintenanceTask)
                        
                        let taskVehicle = TaskVehicle(taskId: maintenanceTask.id, vin: vehicle.id)
                        try await services.maintenanceService.addTaskVehicle(taskVehicle)
                    }
                }
                
                await MainActor.run {
                    isSubmitting = false
                    dismiss()
                    onComplete?(endOdometer, note)
                }
            } catch {
                print("Failed to complete trip: \(error)")
                await MainActor.run {
                    isSubmitting = false
                }
            }
        }
    }
}

import SwiftUI
import Supabase

struct EndTripView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var localStore: LocalDataStore
    @EnvironmentObject var locationService: LocationManager

    let trip: Trip
    let services: AppServices
    var onComplete: ((_ finalOdometer: String, _ notes: String) -> Void)? = nil

    @State private var endOdometer: String = ""
    @State private var endFuel: String = ""
    @State private var isSubmitting: Bool = false
    @State private var previousOdometer: Double = 0.0
    @State private var showAlert = false
    @State private var alertMessage = ""

    @StateObject private var inspectionViewModel = InspectionViewModel()

    private var isFormValid: Bool {
        let trimmedOdo = endOdometer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let odoVal = Double(trimmedOdo), odoVal >= previousOdometer else { return false }
        let trimmedFuel = endFuel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let fuelVal = Int(trimmedFuel), fuelVal >= 0, fuelVal <= 100 else { return false }
        return inspectionViewModel.isComplete
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
                                Text("VEHICLE READINGS")
                                    .font(.system(size: 11, weight: .black))
                                    .foregroundColor(.secondary)
                                    .tracking(1.0)
                            }
                            
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "speedometer")
                                        .foregroundColor(.secondary)
                                    Text("Final Odometer *")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                }
                                
                                HStack(spacing: 6) {
                                    TextField("e.g. \(Int(previousOdometer))", text: $endOdometer)
                                        .keyboardType(.numberPad)
                                        .font(.subheadline)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
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

                            Divider()

                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "fuelpump.fill")
                                        .foregroundColor(.secondary)
                                    Text("Final Fuel Level *")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                }
                                
                                HStack(spacing: 8) {
                                    TextField("e.g. 75", text: $endFuel)
                                        .keyboardType(.numberPad)
                                        .font(.subheadline)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                    
                                    Text("%")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                if !endFuel.isEmpty {
                                    if let val = Int(endFuel), (val < 0 || val > 100) {
                                        Text("Fuel level must be between 0 and 100")
                                            .font(.caption2)
                                            .foregroundColor(.red)
                                            .padding(.top, 2)
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.02), radius: 8, y: 4)

                        // 2. Inspection Checklist
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "checklist")
                                    .foregroundColor(.blue)
                                    .font(.headline)
                                Text("VEHICLE INSPECTION CHECKLIST")
                                    .font(.system(size: 11, weight: .black))
                                    .foregroundColor(.secondary)
                                    .tracking(1.0)
                            }

                            ForEach(inspectionViewModel.items) { item in
                                InspectionRow(item: item) { newStatus in
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        inspectionViewModel.updateStatus(for: item.id, to: newStatus)
                                    }
                                } onDetailsChange: { desc, img in
                                    inspectionViewModel.updateDetails(for: item.id, description: desc, image: img)
                                }
                            }
                        }

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
        .alert("Error", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
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

        let failedItems = inspectionViewModel.items.filter { $0.status == .failed }

        Task {
            do {
                guard let vehicleId = trip.vehicleId else {
                    await showError("No vehicle assigned to this trip. Cannot perform inspection.")
                    return
                }
                guard let driverId = trip.driverId else {
                    await showError("No driver assigned to this trip. Cannot perform inspection.")
                    return
                }

                // 1. Persist inspection to Supabase
                let inspection = VehicleInspection(
                    id: UUID(),
                    tripId: trip.id,
                    vehicleId: vehicleId,
                    driverId: driverId,
                    type: "post_trip",
                    status: failedItems.isEmpty ? "passed" : "failed",
                    odometerReading: Double(endOdometer),
                    fuelLevel: Double(endFuel),
                    notes: nil,
                    createdAt: Date()
                )
                let saved = try await services.inspectionService.createInspection(inspection)

                for item in inspectionViewModel.items {
                    let dbItem = InspectionItemDB(
                        id: UUID(),
                        inspectionId: saved.id,
                        itemName: item.name,
                        status: item.status == .passed ? "pass" : (item.status == .failed ? "fail" : "untested"),
                        failDescription: item.failDescription.isEmpty ? nil : item.failDescription,
                        failPhotoUrl: nil,
                        createdAt: Date()
                    )
                    try await services.inspectionService.createInspectionItem(dbItem)
                }

                // 2. Complete the trip
                var updatedTrip = trip
                let odoDouble = Double(endOdometer) ?? 0.0
                updatedTrip.finalOdometer = odoDouble
                updatedTrip.finalFuelLevel = Double(endFuel) ?? 50
                updatedTrip.status = .completed
                updatedTrip.endTime = Date()
                updatedTrip.driverNote = failedItems.isEmpty ? "Post-trip check completed normally." : "Post-trip inspection failed."

                _ = try await services.tripService.updateTrip(updatedTrip)
                UserDefaults.standard.removeObject(forKey: "trip_\(trip.id.uuidString)_paused")

                // 3. Update vehicle odometer
                var vehicle = try await services.vehicleService.fetchVehicle(id: vehicleId)
                vehicle.odometer = odoDouble

                if !failedItems.isEmpty {
                    // Create work orders for failed items
                    for item in failedItems {
                        var photoUrls: [String] = []
                        if let image = item.failImage,
                           let imageData = image.jpegData(compressionQuality: 0.8) {
                            let photoId = UUID()
                            let storage = services.supabase.client.storage.from("maintenance")
                            let pathName = "\(photoId.uuidString).jpg"
                            do {
                                try await storage.upload(path: pathName, file: imageData, options: FileOptions(contentType: "image/jpeg"))
                                if let publicUrl = try? storage.getPublicURL(path: pathName).absoluteString {
                                    photoUrls.append(publicUrl)
                                }
                            } catch {
                                print("Failed to upload defect image: \(error)")
                            }
                        }

                        let description = "Post-trip inspection failed for \(item.name) on vehicle \(vehicle.licencePlate) (VIN: \(vehicle.id.uuidString)). Odometer: \(endOdometer) km, Fuel: \(endFuel)%. Details: \(item.failDescription)"

                        let personnelList = try? await services.userManagementService.fetchMaintenancePersonnel()
                        let activePersonnel = personnelList?.first(where: { $0.status == .active })

                        let maintenanceTask = MaintenanceTask(
                            id: UUID(),
                            title: item.name,
                            description: description,
                            scheduledDate: DateOnly(wrappedValue: Date()),
                            isUrgent: true,
                            scheduledBy: nil,
                            executedBy: activePersonnel?.id,
                            status: activePersonnel != nil ? .assigned : .scheduled,
                            reportedDate: nil,
                            completedAt: nil,
                            timeTakenHours: nil,
                            partsSummary: nil,
                            totalCost: nil,
                            photoUrls: photoUrls.isEmpty ? nil : photoUrls,
                            elapsedTime: 0
                        )
                        _ = try await services.maintenanceService.createTask(maintenanceTask)
                        let taskVehicle = TaskVehicle(taskId: maintenanceTask.id, vin: vehicle.id)
                        try await services.maintenanceService.addTaskVehicle(taskVehicle)
                    }

                    let postTripNotification = AppNotification(
                        id: UUID(),
                        title: "Post-trip Inspection Failed",
                        message: "\(failedItems.count) defect(s) found on \(vehicle.licencePlate). Work order(s) created for: \(failedItems.map(\.name).joined(separator: ", ")).",
                        type: "work_order_assigned",
                        isRead: false,
                        referenceId: trip.id,
                        recipientId: nil,
                        createdAt: Date()
                    )
                    _ = try? await services.notificationService.createNotification(postTripNotification)

                    vehicle.status = .inMaintenance
                    vehicle.driverId = nil
                }

                _ = try await services.vehicleService.updateVehicle(vehicle)

                await MainActor.run {
                    isSubmitting = false
                    locationService.stopTracking()
                    dismiss()
                    onComplete?(endOdometer, failedItems.isEmpty ? "Post-trip check completed normally." : "Post-trip inspection failed.")
                }
            } catch {
                print("Failed to complete post-trip inspection: \(error)")
                await MainActor.run {
                    isSubmitting = false
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }

    private func showError(_ message: String) async {
        await MainActor.run {
            alertMessage = message
            showAlert = true
            isSubmitting = false
        }
    }
}

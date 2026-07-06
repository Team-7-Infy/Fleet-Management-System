import SwiftUI
import PhotosUI
import Supabase

struct InspectionView: View {
    let services: AppServices
    let trip: InspectionTrip
    let isPresentedModally: Bool
    let vehicleNumber: String
    var onBack: (() -> Void)? = nil
    var onComplete: (() -> Void)? = nil
    var isPostTrip: Bool = false

    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showingComplaintRaisedAnimation = false
    @State private var animationMessage = ""
    @State private var pulseScale: CGFloat = 1.0
    @State private var replacementVehicle: Vehicle? = nil
    @State private var vehicle: Vehicle? = nil

    @StateObject private var viewModel = InspectionViewModel()
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var localStore: LocalDataStore

    @State private var odometerInput: String = ""
    @State private var fuelInput: String = ""

    private var currentOdometer: Int {
        let seed = trip.tripId.filter { "0123456789".contains($0) }
        let number = (Int(seed) ?? 84) % 10000
        return 124000 + (number * 120)
    }

    private var previousOdometer: Double {
        vehicle?.odometer ?? Double(currentOdometer)
    }

    private var currentFuelLevel: Int {
        let seed = trip.tripId.filter { "0123456789".contains($0) }
        let number = (Int(seed) ?? 75) % 25
        return 75 + number
    }

    private var isSubmitEnabled: Bool {
        let hasFailedDefect = viewModel.items.contains { item in
            item.status == .failed && !item.failDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard hasFailedDefect || viewModel.isComplete else { return false }
        
        let trimmedOdo = odometerInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let odoVal = Double(trimmedOdo), odoVal >= previousOdometer else { return false }
        
        let trimmedFuel = fuelInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if let fuelVal = Int(trimmedFuel), fuelVal >= 0 && fuelVal <= 100 {
            return true
        }
        return false
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }

            VStack(spacing: 0) {
                // Header View
                VStack(spacing: 8) {
                    ZStack {
                        Text(isPostTrip ? "Post-Trip Inspection" : "Pre-Trip Inspection")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        HStack {
                            Spacer()
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white.opacity(0.85))
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    
                    Text("Verify vehicle safety before starting trip")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.bottom, 16)
                }
                .background(
                    LinearGradient(colors: [Color(hex: 0x1E3A8A), Color(hex: 0x2563EB)], startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea(edges: .top)
                )

                ScrollView {
                    VStack(spacing: 16) {
                        
                        // Odometer & Fuel Level Required Inputs Card
                        VStack(alignment: .leading, spacing: 16) {
                            Text("VEHICLE READINGS")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                                .padding(.bottom, 4)
                            
                            // Odometer Input Field
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "speedometer")
                                        .foregroundColor(.secondary)
                                    Text("Current Odometer *")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                }
                                
                                HStack(spacing: 6) {
                                    TextField("e.g. \(Int(previousOdometer))", text: $odometerInput)
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
                                
                                if let val = Double(odometerInput), val < previousOdometer {
                                    Text("Odometer must be at least \(Int(previousOdometer)) km")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .padding(.top, 2)
                                }
                            }
                            
                            Divider()
                            
                            // Fuel Level Input Field
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "fuelpump.fill")
                                        .foregroundColor(.secondary)
                                    Text("Current Fuel Level *")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                }
                                
                                HStack(spacing: 8) {
                                    TextField("e.g. \(currentFuelLevel)", text: $fuelInput)
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
                                
                                // Show a warning if fuel level is invalid
                                if !fuelInput.isEmpty {
                                    if let val = Int(fuelInput), (val < 0 || val > 100) {
                                        Text("Fuel level must be between 0 and 100")
                                            .font(.caption2)
                                            .foregroundColor(.red)
                                            .padding(.top, 2)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)

                        ForEach(viewModel.items) { item in
                            InspectionRow(item: item) { newStatus in
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    viewModel.updateStatus(for: item.id, to: newStatus)
                                }
                            } onDetailsChange: { desc, img in
                                viewModel.updateDetails(for: item.id, description: desc, image: img)
                            }
                        }
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
                .background(
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                )

                // 3. Submit Area (Sticks to bottom)
                VStack {
                    Divider()
                    Button(action: submitInspection) {
                        HStack {
                            Spacer()
                            if viewModel.isSubmitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .padding(.trailing, 8)
                            }
                            Text(viewModel.isSubmitting ? "Uploading Report..." : "Submit Inspection")
                                .font(.headline)
                                .fontWeight(.bold)
                            Spacer()
                        }
                        .padding()
                        .background(isSubmitEnabled ? Color.green : Color.gray.opacity(0.3))
                        .foregroundColor(isSubmitEnabled ? .white : .gray)
                        .cornerRadius(16)
                    }
                    .disabled(!isSubmitEnabled || viewModel.isSubmitting)
                    .padding()
                }
                .background(Color(UIColor.secondarySystemGroupedBackground))
            }
            
            if showingComplaintRaisedAnimation {
                ZStack {
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack {
                        Spacer()
                        
                        VStack(spacing: 20) {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.blue)
                                .padding(.top, 12)
                            
                            Text("Vehicle Scheduled for Inspection")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                            
                            Divider()
                            
                            if let replacement = replacementVehicle {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Next Assigned Vehicle")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                        .padding(.bottom, 4)
                                    
                                    HStack {
                                        Text("Licence Plate")
                                            .font(.footnote)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text(replacement.licencePlate)
                                            .font(.footnote)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                    }
                                    
                                    HStack {
                                        Text("Make / Model")
                                            .font(.footnote)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("\(replacement.make) \(replacement.model)")
                                            .font(.footnote)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                    }
                                    
                                    HStack {
                                        Text("Type")
                                            .font(.footnote)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text(replacement.vehicleType.capitalized)
                                            .font(.footnote)
                                            .foregroundColor(.primary)
                                    }
                                }
                                .padding()
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .cornerRadius(12)
                            } else {
                                Text("No replacement vehicle currently available. Please contact dispatch.")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.vertical, 8)
                            }
                            
                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    showingComplaintRaisedAnimation = false
                                }
                                dismiss()
                                onComplete?()
                            }) {
                                Text("Done")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.blue)
                                    .cornerRadius(12)
                            }
                            .padding(.top, 8)
                        }
                        .padding(24)
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 10)
                        .padding(.horizontal, 36)
                        
                        Spacer()
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .zIndex(100)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK")) {
                    dismiss()
                    onComplete?()
                }
            )
        }
        .task {
            if let tripUuid = UUID(uuidString: trip.tripId),
               let tripModel = try? await services.tripService.fetchTrip(id: tripUuid),
               let fetchedVehicle = try? await services.vehicleService.fetchVehicle(id: tripModel.vehicleId ?? UUID()) {
                self.vehicle = fetchedVehicle
            }
        }
    }

    private func persistInspection(tripId: UUID, vehicleId: UUID, driverId: UUID) async throws {
        let inspectionType = isPostTrip ? "post_trip" : "pre_trip"
        let failedItems = viewModel.items.filter { $0.status == .failed }
        let inspectionStatus = failedItems.isEmpty ? "passed" : "failed"

        let inspection = VehicleInspection(
            id: UUID(),
            tripId: tripId,
            vehicleId: vehicleId,
            driverId: driverId,
            type: inspectionType,
            status: inspectionStatus,
            odometerReading: Double(odometerInput),
            fuelLevel: Double(fuelInput),
            notes: nil,
            createdAt: Date()
        )
        let saved = try await services.inspectionService.createInspection(inspection)

        for item in viewModel.items {
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
    }

    private func showAlert(title: String, message: String) async {
        await MainActor.run {
            alertTitle = title
            alertMessage = message
            showingAlert = true
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

    private func submitInspection() {
        viewModel.isSubmitting = true
        
        let failedItems = viewModel.items.filter { $0.status == .failed }
        
        // Save readings to UserDefaults under trip ID
        if let odoVal = Int(odometerInput), let fuelVal = Int(fuelInput) {
            let keyPrefix = isPostTrip ? "post" : "pre"
            UserDefaults.standard.set(odoVal, forKey: "trip_\(trip.tripId)_\(keyPrefix)_odo")
            UserDefaults.standard.set(fuelVal, forKey: "trip_\(trip.tripId)_\(keyPrefix)_fuel")
        }

        guard !failedItems.isEmpty else {
            // No defects found, persist and proceed normally
            Task {
                do {
                    guard let tripUuid = UUID(uuidString: trip.tripId) else { return }
                    let tripModel = try await services.tripService.fetchTrip(id: tripUuid)
                    guard let vehicleId = tripModel.vehicleId else {
                        await showAlert(title: "No Vehicle", message: "No vehicle assigned to this trip. Cannot perform inspection.")
                        return
                    }
                    guard let driverId = tripModel.driverId else {
                        await showAlert(title: "No Driver", message: "No driver assigned to this trip. Cannot perform inspection.")
                        return
                    }

                    try await persistInspection(tripId: tripUuid, vehicleId: vehicleId, driverId: driverId)

                    var vehicleModel = try await services.vehicleService.fetchVehicle(id: vehicleId)
                    if let odoVal = Double(odometerInput) {
                        vehicleModel.odometer = odoVal
                        _ = try await services.vehicleService.updateVehicle(vehicleModel)
                    }
                } catch {
                    print("Failed to persist inspection: \(error)")
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                viewModel.isSubmitting = false
                if !isPostTrip {
                    localStore.markTripInspected(trip.tripId)
                }
                dismiss()
                onComplete?()
            }
            return
        }
        
        // Defects found! Persist, then handle work order and auto-reassign vehicle
        Task {
            do {
                guard let tripUuid = UUID(uuidString: trip.tripId) else {
                    throw NSError(domain: "FMS", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Trip ID"])
                }
                
                // 1. Fetch current trip and vehicle
                let tripModel = try await services.tripService.fetchTrip(id: tripUuid)
                guard let vehicleId = tripModel.vehicleId else {
                    await showAlert(title: "No Vehicle", message: "No vehicle assigned to this trip. Cannot perform inspection.")
                    return
                }
                guard let driverId = tripModel.driverId else {
                    await showAlert(title: "No Driver", message: "No driver assigned to this trip. Cannot perform inspection.")
                    return
                }

                // 2. Persist inspection to Supabase before creating work orders
                try await persistInspection(tripId: tripUuid, vehicleId: vehicleId, driverId: driverId)

                let vehicle = try await services.vehicleService.fetchVehicle(id: vehicleId)

                // 3. Loop over each failed item and create a separate work order (maintenance task) in DB
                for item in failedItems {
                    var photoUrls: [String] = []
                    
                    // Upload photo to Supabase storage if taken
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
                            print("Failed to upload defect image for \(item.name): \(error)")
                        }
                    }
                    
                    let prefix = isPostTrip ? "Post-trip" : "Pre-trip"
                    let description = "\(prefix) inspection failed for \(item.name) on vehicle \(vehicle.licencePlate) (VIN: \(vehicle.id.uuidString)). Odometer: \(odometerInput) km, Fuel: \(fuelInput)%. Details: \(item.failDescription)"
                    
                    // Fetch active maintenance personnel to assign
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
                    
                    // Link vehicle to the task in DB
                    let taskVehicle = TaskVehicle(taskId: maintenanceTask.id, vin: vehicle.id)
                    try await services.maintenanceService.addTaskVehicle(taskVehicle)
                }
                
                // 4. Update the vehicle status to .maintenance and clear its driver in DB
                var updatedVehicle = vehicle
                updatedVehicle.status = .inMaintenance
                updatedVehicle.driverId = nil
                if let odoVal = Double(odometerInput) {
                    updatedVehicle.odometer = odoVal
                }
                _ = try await services.vehicleService.updateVehicle(updatedVehicle)
                
                // 5. Scan for an available active vehicle of the same type
                let allVehicles = try await services.vehicleService.fetchVehicles()
                let allTrips = try await services.tripService.fetchTrips()
                let busyVehicleIds = Set(allTrips.filter {
                    $0.status == .inProgress || $0.status == .accepted || $0.status == .scheduled || $0.status == .pending || $0.status == .rejectionPending
                }.map { $0.vehicleId })
                
                let replacementVehicle = allVehicles.first { v in
                    v.status == .available &&
                    v.vehicleType == vehicle.vehicleType &&
                    v.id != vehicle.id &&
                    !busyVehicleIds.contains(v.id)
                }
                
                if let replacement = replacementVehicle {
                    // Update replacement vehicle to assign the driver in DB
                    var repVehicle = replacement
                    repVehicle.driverId = tripModel.driverId
                    _ = try await services.vehicleService.updateVehicle(repVehicle)
                    
                    // Update trip to use the replacement vehicle in DB
                    var updatedTrip = tripModel
                    updatedTrip.vehicleId = replacement.id
                    _ = try await services.tripService.updateTrip(updatedTrip)
                    
                    await MainActor.run {
                        viewModel.isSubmitting = false
                        localStore.markTripInspected(trip.tripId)
                        self.replacementVehicle = replacement
                        self.animationMessage = "Vehicle \(vehicle.licencePlate) has been sent to maintenance. \(failedItems.count) separate work order(s) created. Vehicle \(replacement.licencePlate) has been automatically assigned to your trip."
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            showingComplaintRaisedAnimation = true
                        }
                    }
                } else {
                    // Mark the trip as rejectionPending to notify the manager that driver rejected/needs re-assignment
                    try await services.tripService.updateTripStatus(id: tripModel.id, status: .rejectionPending, rejectionReason: "Pre-trip inspection failed. No replacement vehicle of type \(vehicle.vehicleType) available.")
                    
                    await MainActor.run {
                        viewModel.isSubmitting = false
                        self.replacementVehicle = nil
                        self.animationMessage = "Vehicle \(vehicle.licencePlate) has been sent to maintenance. \(failedItems.count) separate work order(s) created. No replacement vehicle of type \(vehicle.vehicleType) is currently available. Please contact dispatch."
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            showingComplaintRaisedAnimation = true
                        }
                    }
                }
            } catch {
                print("Failed to execute pre-trip defect workflow: \(error)")
                await MainActor.run {
                    viewModel.isSubmitting = false
                    alertTitle = "Error"
                    alertMessage = "Failed to process inspection report. Please check your network and try again."
                    showingAlert = true
                }
            }
        }
    }
}

// MARK: - Custom Reusable Row
struct InspectionRow: View {
    let item: InspectionItem
    let onStatusChange: (InspectionItem.ItemStatus) -> Void
    let onDetailsChange: (String, UIImage?) -> Void

    @State private var failDescription: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var showingCamera = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Image(systemName: item.icon)
                        .foregroundColor(.blue)
                        .font(.system(size: 20))
                }

                Text(item.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                // Pass/Fail Action Buttons
                HStack(spacing: 8) {
                    // Fail Button
                    Button(action: {
                        onStatusChange(.failed)
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(item.status == .failed ? .white : .red)
                            .frame(width: 40, height: 40)
                            .background(item.status == .failed ? Color.red : Color.red.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel("Mark \(item.name) as Failed")

                    // Pass Button
                    Button(action: {
                        onStatusChange(.passed)
                    }) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(item.status == .passed ? .white : .green)
                            .frame(width: 40, height: 40)
                            .background(item.status == .passed ? Color.green : Color.green.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel("Mark \(item.name) as Passed")
                }
            }
            .padding()

            if item.status == .failed {
                VStack(alignment: .leading, spacing: 16) {
                    Divider()
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Mandatory Proof")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)

                        HStack(spacing: 16) {
                            Button(action: { showingCamera = true }) {
                                if let image = selectedImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 72, height: 72)
                                        .cornerRadius(12)
                                        .clipped()
                                } else {
                                    VStack(spacing: 6) {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.blue)
                                        Text("Take Photo")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.blue)
                                    }
                                    .frame(width: 72, height: 72)
                                    .background(Color.blue.opacity(0.08))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.blue.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4]))
                                    )
                                }
                            }
                            .sheet(isPresented: $showingCamera) {
                                CameraPicker(selectedImage: Binding(
                                    get: { selectedImage },
                                    set: { newImage in
                                        selectedImage = newImage
                                        onDetailsChange(failDescription, newImage)
                                    }
                                ))
                            }

                            if selectedImage != nil {
                                Button(action: {
                                    selectedPhotoItem = nil
                                    selectedImage = nil
                                    onDetailsChange(failDescription, nil)
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "trash.fill")
                                        Text("Remove")
                                    }
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.red.opacity(0.08))
                                    .cornerRadius(8)
                                }
                            } else {
                                Text("Please upload an image proof of the issue.")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Description *")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.red)

                            TextField("Describe the issue in detail...", text: $failDescription)
                                .padding()
                                .font(.subheadline)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(failDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1)
                                )
                                .onChange(of: failDescription) { newValue in
                                    onDetailsChange(newValue, selectedImage)
                                }
                        }
                    }
                    .padding([.horizontal, .bottom])
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
        .onAppear {
            failDescription = item.failDescription
            selectedImage = item.failImage
        }
    }
}

// MARK: - Camera Picker Representable
struct CameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedImage: UIImage?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
        } else {
            picker.sourceType = .photoLibrary
        }
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

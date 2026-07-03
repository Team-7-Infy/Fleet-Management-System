import SwiftUI
import PhotosUI

struct InspectionView: View {
    let trip: InspectionTrip
    let isPresentedModally: Bool
    let vehicleNumber: String
    var onBack: (() -> Void)? = nil
    var onComplete: (() -> Void)? = nil

    @StateObject private var viewModel = InspectionViewModel()
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var localStore: LocalDataStore

    @State private var odometerInput: String = ""
    @State private var fuelInput: String = ""
    @State private var selectedFuelPhoto: PhotosPickerItem? = nil

    private var currentOdometer: Int {
        let seed = trip.tripId.filter { "0123456789".contains($0) }
        let number = (Int(seed) ?? 84) % 10000
        return 124000 + (number * 120)
    }

    private var currentFuelLevel: Int {
        let seed = trip.tripId.filter { "0123456789".contains($0) }
        let number = (Int(seed) ?? 75) % 25
        return 75 + number
    }

    private var isSubmitEnabled: Bool {
        guard viewModel.isComplete else { return false }
        
        let trimmedOdo = odometerInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOdo.isEmpty, Int(trimmedOdo) != nil else { return false }
        
        let trimmedFuel = fuelInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if let fuelVal = Int(trimmedFuel), fuelVal >= 0 && fuelVal <= 100 {
            return true
        }
        return false
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                // Gradient Header extending under safe area
                VStack(spacing: 16) {
                    // Top Bar: Centered title and Close button
                    ZStack {
                        Text("Inspection")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        HStack {
                            Spacer()
                            Button(action: {
                                if let onBack = onBack {
                                    onBack()
                                } else {
                                    dismiss()
                                }
                            }) {
                                textClose
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 44) // Safety space for notch / top screen
                    
                    // Vehicle Info row
                    HStack(spacing: 12) {
                        Image(systemName: "shield.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Daily Safety Inspection")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Text("Vehicle: \(vehicleNumber)")
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

                // 2. Interactive Checklist
                ScrollView {
                    VStack(spacing: 16) {
                        
                        // Odometer & Fuel Level Required Inputs Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "square.and.pencil")
                                    .foregroundColor(.blue)
                                    .font(.headline)
                                Text("REQUIRED METER READINGS")
                                    .font(.system(size: 11, weight: .black))
                                    .foregroundColor(.secondary)
                                    .tracking(1.0)
                            }
                            .padding(.bottom, 4)
                            
                            // Odometer Input Field
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: "speedometer")
                                        .foregroundColor(.secondary)
                                    Text("Current Odometer *")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    HStack(spacing: 4) {
                                        TextField("e.g. \(currentOdometer)", text: $odometerInput)
                                            .keyboardType(.numberPad)
                                            .multilineTextAlignment(.trailing)
                                            .font(.subheadline)
                                            .frame(width: 120)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(8)
                                        Text("km")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                            .fixedSize()
                                    }
                                }
                            }
                            
                            Divider()
                            
                            // Fuel Level Input Field
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: "fuelpump.fill")
                                        .foregroundColor(.secondary)
                                    Text("Current Fuel Level *")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    HStack(spacing: 8) {
                                        TextField("e.g. \(currentFuelLevel)", text: $fuelInput)
                                            .keyboardType(.numberPad)
                                            .multilineTextAlignment(.trailing)
                                            .font(.subheadline)
                                            .frame(width: 90)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(8)
                                        
                                        PhotosPicker(selection: $selectedFuelPhoto, matching: .images) {
                                            Image(systemName: "camera.viewfinder")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.blue)
                                                .frame(width: 32, height: 32)
                                                .background(Color.blue.opacity(0.08))
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                        .accessibilityLabel("Scan Fuel Gauge")
                                        
                                        Text("%")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                            .fixedSize()
                                    }
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
        }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: selectedFuelPhoto) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    OCRService.extractFuelLevel(from: uiImage) { level in
                        DispatchQueue.main.async {
                            if let level = level {
                                fuelInput = String(level)
                                HapticManager.shared.triggerImpact(style: .medium)
                            } else {
                                HapticManager.shared.triggerNotification(type: .warning)
                            }
                        }
                    }
                }
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

    private func submitInspection() {
        viewModel.isSubmitting = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            viewModel.isSubmitting = false
            localStore.markTripInspected(trip.tripId)
            
            // Save readings to UserDefaults under trip ID
            if let odoVal = Int(odometerInput), let fuelVal = Int(fuelInput) {
                UserDefaults.standard.set(odoVal, forKey: "trip_\(trip.tripId)_pre_odo")
                UserDefaults.standard.set(fuelVal, forKey: "trip_\(trip.tripId)_pre_fuel")
            }

            dismiss()
            onComplete?()
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
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
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
                                        Text("Add Photo")
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
                            .onChange(of: selectedPhotoItem) { newItem in
                                Task {
                                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                                       let uiImage = UIImage(data: data) {
                                        await MainActor.run {
                                            self.selectedImage = uiImage
                                            onDetailsChange(failDescription, uiImage)
                                        }
                                    }
                                }
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

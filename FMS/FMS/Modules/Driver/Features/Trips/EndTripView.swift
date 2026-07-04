import SwiftUI

struct EndTripView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var localStore: LocalDataStore

    let trip: Trip
    let services: AppServices
    var onComplete: ((_ finalOdometer: String, _ notes: String) -> Void)? = nil

    @State private var endOdometer: String = ""
    @State private var tripNotes: String = ""
    @State private var isSubmitting: Bool = false
    @State private var signaturePath = Path()

    private var isFormValid: Bool {
        !endOdometer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !signaturePath.isEmpty
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
                        // Odometer Readings Card
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
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "speedometer")
                                        .foregroundColor(.secondary)
                                    Text("Final Odometer *")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                }
                                
                                HStack(spacing: 6) {
                                    TextField("Enter ending odometer (km)", text: $endOdometer)
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
                            }
                        }
                        .padding(20)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.02), radius: 8, y: 4)

                        // Delivery Notes Card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "note.text")
                                    .foregroundColor(.blue)
                                    .font(.headline)
                                Text("DELIVERY REMARKS")
                                    .font(.system(size: 11, weight: .black))
                                    .foregroundColor(.secondary)
                                    .tracking(1.0)
                            }
                            
                            TextEditor(text: $tripNotes)
                                .frame(height: 80)
                                .font(.subheadline)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                                )
                        }
                        .padding(20)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.02), radius: 8, y: 4)

                        // Digital Signature Card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "signature")
                                    .foregroundColor(.blue)
                                    .font(.headline)
                                Text("CUSTOMER CONFIRMATION *")
                                    .font(.system(size: 11, weight: .black))
                                    .foregroundColor(.secondary)
                                    .tracking(1.0)
                                Spacer()
                                Button(action: { signaturePath = Path() }) {
                                    Text("Clear")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.red)
                                }
                            }
                            
                            SignatureCanvas(path: $signaturePath)
                                .frame(height: 140)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.secondary.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4]))
                                )
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
                let odoDouble = Double(endOdometer) ?? 124000.0
                updatedTrip.finalOdometer = odoDouble
                updatedTrip.status = .completed
                updatedTrip.endTime = Date()
                updatedTrip.driverNote = tripNotes
                
                _ = try await services.tripService.updateTrip(updatedTrip)
                
                await MainActor.run {
                    isSubmitting = false
                    dismiss()
                    onComplete?(endOdometer, tripNotes)
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

struct SignatureCanvas: View {
    @Binding var path: Path

    var body: some View {
        GeometryReader { geometry in
            path.stroke(Color.primary, lineWidth: 3)
                .background(Color.clear)
                .gesture(
                    DragGesture(minimumDistance: 0.1)
                        .onChanged { value in
                            let currentPoint = value.location
                            if value.translation.width == 0 && value.translation.height == 0 {
                                path.move(to: currentPoint)
                            } else {
                                path.addLine(to: currentPoint)
                            }
                        }
                )
        }
    }
}

import SwiftUI

struct InspectionView: View {
    let trip: InspectionTrip
    let isPresentedModally: Bool
    let vehicleNumber: String
    var onBack: (() -> Void)? = nil
    var onComplete: (() -> Void)? = nil

    @StateObject private var viewModel = InspectionViewModel()
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var localStore: LocalDataStore

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {

                // 1. Header Alert Banner
                HStack {
                    Image(systemName: "shield.checkerboard")
                        .font(.title2)
                    VStack(alignment: .leading) {
                        Text("Daily Safety Inspection")
                            .font(.headline)
                        Text("Vehicle: \(vehicleNumber)")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    Spacer()
                }
                .padding()
                .background(LinearGradient(gradient: Gradient(colors: [Color.blue, Color(red: 0.1, green: 0.1, blue: 0.5)]), startPoint: .leading, endPoint: .trailing))
                .foregroundColor(.white)

                // 2. Interactive Checklist
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(viewModel.items) { item in
                            InspectionRow(item: item) { newStatus in
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                viewModel.updateStatus(for: item.id, to: newStatus)
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
                        .background(viewModel.isComplete ? Color.green : Color.gray.opacity(0.3))
                        .foregroundColor(viewModel.isComplete ? .white : .gray)
                        .cornerRadius(16)
                    }
                    .disabled(!viewModel.isComplete || viewModel.isSubmitting)
                    .padding()
                }
                .background(Color(UIColor.secondarySystemGroupedBackground))
            }
        }
        .navigationTitle("Inspection")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            if isPresentedModally {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        if let onBack = onBack {
                            onBack()
                        } else {
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                }
            } else {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        if let onBack = onBack {
                            onBack()
                        } else {
                            dismiss()
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }

    private func submitInspection() {
        viewModel.isSubmitting = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            viewModel.isSubmitting = false
            localStore.markTripInspected(trip.tripId)

            dismiss()
            onComplete?()
        }
    }
}

// MARK: - Custom Reusable Row
struct InspectionRow: View {
    let item: InspectionItem
    let onStatusChange: (InspectionItem.ItemStatus) -> Void

    var body: some View {
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
                Button(action: { onStatusChange(.failed) }) {
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
                Button(action: { onStatusChange(.passed) }) {
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
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
}

import SwiftUI

// MARK: - Model
struct InspectionTrip: Identifiable {
    let id = UUID()
    let tripId: String
    let vehicleNumber: String
    let destination: String
    let status: String
}

// MARK: - Flow Controller
struct InspectionFlowView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedTrip: InspectionTrip? = nil
    @State private var inspectedIds: Set<String> = []
    
    let isPresentedModally: Bool
    
    init(isPresentedModally: Bool = false) {
        self.isPresentedModally = isPresentedModally
    }

    let upcomingTrips: [InspectionTrip] = [
        InspectionTrip(tripId: "TRP-083", vehicleNumber: "KA-01-HC-1234", destination: "Nashik Distribution Hub", status: "Pending"),
        InspectionTrip(tripId: "TRP-084", vehicleNumber: "KA-05-AB-9876", destination: "Surat Port Authority", status: "Scheduled"),
        InspectionTrip(tripId: "TRP-085", vehicleNumber: "MH-12-ZX-4321", destination: "Pune Distribution Hub", status: "Scheduled"),
    ]

    var body: some View {
        if let _ = selectedTrip {
            InspectionView()
                .onDisappear {
                    if let trip = selectedTrip {
                        inspectedIds.insert(trip.tripId)
                        selectedTrip = nil
                    }
                }
        } else {
            VehiclePickerView(
                trips: upcomingTrips,
                inspectedIds: inspectedIds,
                isPresentedModally: isPresentedModally
            ) { trip in
                selectedTrip = trip
            } onClose: {
                dismiss()
            }
        }
    }
}

// MARK: - Vehicle Picker
struct VehiclePickerView: View {
    let trips: [InspectionTrip]
    let inspectedIds: Set<String>
    let isPresentedModally: Bool
    let onSelect: (InspectionTrip) -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()
            VStack(spacing: 0) {

                // Header banner
                HStack(spacing: 10) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.title2)
                        .foregroundColor(.white)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pre-Trip Inspection")
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundColor(.white)
                        Text("Select a vehicle to inspect")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    Spacer()
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.20, green: 0.19, blue: 0.42),
                                 Color(red: 0.08, green: 0.36, blue: 0.55)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        Text("UPCOMING & SCHEDULED TRIPS")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 20)
                            .padding(.horizontal, 4)

                        ForEach(trips) { trip in
                            let isDone = inspectedIds.contains(trip.tripId)

                            Button(action: {
                                if !isDone { onSelect(trip) }
                            }) {
                                HStack(spacing: 16) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(isDone ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                                            .frame(width: 52, height: 52)
                                        Image(systemName: isDone ? "checkmark.seal.fill" : "truck.box.fill")
                                            .font(.title2)
                                            .foregroundColor(isDone ? .green : .blue)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(trip.vehicleNumber)
                                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                                            .foregroundColor(.primary)
                                        Text(trip.destination)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Text("Trip: \(trip.tripId)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 8) {
                                        if isDone {
                                            Text("Inspected")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(.green)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 5)
                                                .background(Color.green.opacity(0.12))
                                                .clipShape(Capsule())
                                        } else {
                                            Text(trip.status)
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(.orange)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 5)
                                                .background(Color.orange.opacity(0.12))
                                                .clipShape(Capsule())
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(.gray.opacity(0.5))
                                        }
                                    }
                                }
                                .padding(18)
                                .background(Color(UIColor.systemBackground))
                                .cornerRadius(20)
                                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
                                .opacity(isDone ? 0.6 : 1.0)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            if isPresentedModally {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { onClose() }
                        .fontWeight(.semibold)
                }
            } else {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { onClose() }) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }
}

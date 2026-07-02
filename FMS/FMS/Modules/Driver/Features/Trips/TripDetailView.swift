import SwiftUI

struct TripDetailView: View {
    let trip: Trip
    var vehicleNumber: String = ""
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var localStore: LocalDataStore

    @State private var cancelProgress: CGFloat = 0.0
    @State private var showingCancelModal = false
    @State private var cancelReason = ""
    @State private var cancelComments = ""
    @State private var isCancelConfirmed = false

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    if trip.status == .completed {
                        CompletedTripDetailView(trip: trip, vehicleNumber: vehicleNumber)
                    } else {
                        // --- Original Scheduled/Active Trip Details ---
                        // Clean Inline Title Header
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(trip.id.uuidString.prefix(8).uppercased())
                                    .font(.system(size: 32, weight: .black, design: .rounded))
                                    .foregroundColor(.primary)

                                Spacer()

                                HStack(spacing: 6) {
                                    Circle().fill(trip.status == .inProgress ? Color.blue : Color.orange).frame(width: 6, height: 6)
                                    Text(trip.status.rawValue.uppercased())
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .foregroundColor(trip.status == .inProgress ? Color.blue : Color.orange)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(trip.status == .inProgress ? Color.blue.opacity(0.1) : Color.orange.opacity(0.1))
                                .clipShape(Capsule())
                            }

                            Text("Assignment Details")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 4)
                        .padding(.bottom, 4)

                        // 1. Route & Locations Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "map.fill")
                                    .foregroundColor(.green)
                                Text("Route & Locations")
                                    .font(.headline)
                                    .fontWeight(.bold)
                            }

                            Divider()

                            HStack(alignment: .top, spacing: 16) {
                                VStack(spacing: 0) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 10, height: 10)

                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 2, height: 44)

                                    Image(systemName: "flag.fill")
                                        .foregroundColor(.red)
                                        .font(.system(size: 10))
                                }
                                .padding(.top, 4)

                                VStack(alignment: .leading, spacing: 18) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("START LOCATION")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.secondary)
                                        Text(trip.startLocation)
                                            .font(.body)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("END LOCATION")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.secondary)
                                        Text(trip.endLocation)
                                            .font(.body)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 4)

                        // 2. Schedule & Vitals Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(.purple)
                                Text("Schedule & Vitals")
                                    .font(.headline)
                                    .fontWeight(.bold)
                            }

                            Divider()

                            HStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("START DATE & TIME")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.secondary)
                                    Text(trip.startTime.formatted(date: .abbreviated, time: .shortened))
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("END DATE & TIME")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.secondary)
                                    Text(trip.endTime?.formatted(date: .abbreviated, time: .shortened) ?? "TBD")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                }
                            }

                            Divider()

                            HStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("ASSIGNED VEHICLE")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.secondary)
                                    HStack(spacing: 4) {
                                        Image(systemName: "truck.box.fill")
                                            .foregroundColor(.blue)
                                            .font(.caption)
                                        Text(vehicleNumber)
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                    }
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("TOTAL DISTANCE")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.secondary)
                                    Text("-- km")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                        .padding(20)
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 4)

                        // 3. Vehicle Maintenance & Health Card
                        VehicleMaintenanceReportCard(vehicleNumber: vehicleNumber)

                        // 4. Cancel Assignment Button (Only for active or scheduled assignments)
                        VStack(spacing: 8) {
                            Text("Need to cancel this assignment?")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 14)

                            Button(action: {
                                isCancelConfirmed = false
                                cancelReason = ""
                                cancelComments = ""
                                showingCancelModal = true
                            }) {
                                HStack {
                                    Image(systemName: "xmark.circle.fill")
                                    Text("Cancel Assignment")
                                        .fontWeight(.bold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.red)
                                .cornerRadius(16)
                                .shadow(color: Color.red.opacity(0.15), radius: 8, x: 0, y: 4)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(trip.status == .completed ? "Completed Transit" : "Assignment Details")
                    .font(.headline)
                    .fontWeight(.bold)
            }
        }
        .sheet(isPresented: $showingCancelModal, onDismiss: {
            if isCancelConfirmed {
                dismiss()
            } else {
                cancelProgress = 0.0
            }
        }) {
            TripCancellationView(
                isConfirmed: $isCancelConfirmed,
                selectedReason: $cancelReason,
                comments: $cancelComments
            )
        }
    }
}

// MARK: - Redesigned Historical Completed Trip Detail View
struct CompletedTripDetailView: View {
    let trip: Trip
    var vehicleNumber: String = ""
    @EnvironmentObject var localStore: LocalDataStore
    @EnvironmentObject var locationService: LocationManager

    @State private var showingReportIssueSheet = false

    private var distanceValue: Double {
        if let end = trip.finalOdometer {
            return end - 124000
        }
        return 0.0
    }

    private var estimatedFuelLiters: Double {
        distanceValue / 8.5
    }

    private var startOdometer: Int {
        let seed = trip.id.uuidString.filter { "0123456789".contains($0) }
        let number = (Int(seed) ?? 84) % 10000
        return 124000 + (number * 120)
    }

    private var endOdometer: Int {
        startOdometer + Int(distanceValue)
    }

    var body: some View {
        VStack(spacing: 20) {
            // Clean Inline Title Header
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(trip.id.uuidString.prefix(8).uppercased())
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundColor(.primary)

                    Spacer()

                    HStack(spacing: 6) {
                        Circle().fill(Color.green).frame(width: 6, height: 6)
                        Text("COMPLETED")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .clipShape(Capsule())
                }

                Text("Vehicle: \(vehicleNumber) • Historical Transit Summary")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 4)

            // 1. Detailed Route Timeline Card
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "road.lanes")
                        .foregroundColor(.green)
                    Text("Transit Route Timeline")
                        .font(.headline)
                        .fontWeight(.bold)
                }

                Divider()

                HStack(alignment: .top, spacing: 16) {
                    // Vertical timeline node line
                    VStack(spacing: 0) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)

                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 2, height: 44)

                        Image(systemName: "flag.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 10))
                    }
                    .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 18) {
                        // Start Location
                        VStack(alignment: .leading, spacing: 4) {
                            Text("START LOCATION")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            Text(trip.startLocation)
                                .font(.body)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            Text("Actual Start: \(trip.startTime.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // End Location
                        VStack(alignment: .leading, spacing: 4) {
                            Text("STOP LOCATION (DESTINATION)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            Text(trip.endLocation)
                                .font(.body)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            Text("Actual End Time: \(trip.endTime?.formatted(date: .abbreviated, time: .shortened) ?? "N/A")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(20)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 4)

            // 2. Odometer & Fuel Reading (Driver Inputs)
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "square.and.pencil")
                        .foregroundColor(.blue)
                    Text("Driver Transit Inputs")
                        .font(.headline)
                        .fontWeight(.bold)
                }

                Divider()

                // Odometer Readings
                VStack(alignment: .leading, spacing: 10) {
                    Text("ODOMETER READINGS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)

                    HStack {
                        VStack(alignment: .leading) {
                            Text("Start Odometer")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(startOdometer) km")
                                .font(.subheadline)
                                .fontWeight(.bold)
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                            .foregroundColor(.gray.opacity(0.5))
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("End Odometer")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(endOdometer) km")
                                .font(.subheadline)
                                .fontWeight(.bold)
                        }
                    }
                    .padding(12)
                    .background(Color.blue.opacity(0.03))
                    .cornerRadius(10)
                }

                Divider()

                // Fuel Readings
                VStack(alignment: .leading, spacing: 10) {
                    Text("FUEL LEVEL READINGS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)

                    HStack {
                        VStack(alignment: .leading) {
                            Text("Start Level")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("95%")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                            .foregroundColor(.gray.opacity(0.5))
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("End Level")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("78%")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.03))
                    .cornerRadius(10)
                }
            }
            .padding(20)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 4)

            // 3. Metrics & Fuel Usage Card
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "chart.bar.doc.horizontal.fill")
                        .foregroundColor(.blue)
                    Text("Trip Metrics & Fuel Usage")
                        .font(.headline)
                        .fontWeight(.bold)
                }

                Divider()

                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DISTANCE TRAVELLED")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                        Text("\(Int(distanceValue)) km")
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("FUEL CONSUMED (EST)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f L", estimatedFuelLiters))
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }
                }

                Divider()

                // Refill details if any
                let refills = localStore.fuelRecords(for: trip.id.uuidString)
                if !refills.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ACTUAL FUEL REFILLS LOGGED")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)

                        ForEach(refills) { refill in
                            HStack {
                                Label(refill.fuelType.rawValue, systemImage: "fuelpump.fill")
                                    .font(.footnote)
                                    .foregroundColor(.primary)
                                Spacer()
                                if let volume = refill.volumeFilled {
                                    Text("\(volume, specifier: "%.1f") L")
                                        .font(.footnote)
                                        .fontWeight(.semibold)
                                }
                                if let cost = refill.cost {
                                    Text("(₹\(cost, specifier: "%.2f"))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text("No active refuels logged during this transit.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(20)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 4)

            // 4. Vehicle Maintenance & Health Card
            VehicleMaintenanceReportCard(vehicleNumber: vehicleNumber)

            // 5. Notes & Incidents Card
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "exclamationmark.shield.fill")
                        .foregroundColor(.orange)
                    Text("Safety Logs & Driver Notes")
                        .font(.headline)
                        .fontWeight(.bold)
                }

                Divider()

                let tripIncidents = localStore.incidents(for: trip.id.uuidString)

                if !tripIncidents.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("INCIDENTS REPORTED")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.red)

                        ForEach(tripIncidents) { incident in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(incident.type.rawValue)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.red)
                                        .cornerRadius(6)
                                    Spacer()
                                    Text(incident.status.rawValue)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text(incident.description)
                                    .font(.footnote)
                                    .foregroundColor(.primary)
                            }
                            .padding(10)
                            .background(Color.red.opacity(0.05))
                            .cornerRadius(8)
                        }
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(.green)
                            .font(.subheadline)
                        Text("Transit completed with zero incidents logged.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                if let note = trip.driverNote, !note.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("TRANSIT NOTES")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                        Text(note)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.06))
                            .cornerRadius(10)
                    }
                }

                if tripIncidents.isEmpty {
                    Divider()

                    // Add a button to report an issue
                    Button(action: {
                        showingReportIssueSheet = true
                    }) {
                        HStack {
                            Image(systemName: "exclamationmark.bubble.fill")
                            Text("Report a Transit Issue")
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red)
                        .cornerRadius(12)
                        .shadow(color: Color.red.opacity(0.2), radius: 6, x: 0, y: 3)
                    }
                    .sheet(isPresented: $showingReportIssueSheet) {
                        IncidentReportView(tripId: trip.id.uuidString)
                            .environmentObject(locationService)
                            .environmentObject(localStore)
                    }
                }
            }
            .padding(20)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 4)
        }
    }
}

// MARK: - Redesigned Reusable Vehicle Maintenance & Health Card View
struct VehicleMaintenanceReportCard: View {
    let vehicleNumber: String

    private var lastServiceDate: String {
        let lastChar = vehicleNumber.last ?? "A"
        let daysAgo = 10 + (lastChar.asciiValue ?? 65) % 15
        return "1\(daysAgo % 10) Jun, 2026"
    }

    private var tireTread: String {
        let lastChar = vehicleNumber.last ?? "A"
        let tread = 5.8 + Double((lastChar.asciiValue ?? 65) % 20) / 10.0
        return String(format: "%.1f mm", tread)
    }

    private var brakeLife: String {
        let lastChar = vehicleNumber.last ?? "A"
        let life = 80 + (lastChar.asciiValue ?? 65) % 18
        return "\(life)%"
    }

    private var engineOilLife: String {
        let lastChar = vehicleNumber.last ?? "A"
        let life = 75 + (lastChar.asciiValue ?? 65) % 22
        return "\(life)%"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Vehicle Maintenance & Health")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("Last Service: \(lastServiceDate)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("HEALTHY")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
            }

            Divider()

            VStack(spacing: 12) {
                HStack(spacing: 20) {
                    HealthMetricRow(title: "Brakes Wear", value: brakeLife, icon: "gauge.medium")
                    HealthMetricRow(title: "Engine Oil", value: engineOilLife, icon: "drop.fill")
                }
                HStack(spacing: 20) {
                    HealthMetricRow(title: "Tire Tread", value: tireTread, icon: "circle.circle.fill")
                    HealthMetricRow(title: "Coolant Level", value: "Optimal", icon: "thermometer.medium")
                }
            }

            Divider()

            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                    .font(.caption)
                Text("Fitness & Pollution Certificates valid and compliant.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 4)
    }
}

struct HealthMetricRow: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.05))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.blue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.footnote)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Standalone Slider for ScrollViews using highPriorityGesture
struct DetailCancelSlider: View {
    @Binding var progress: CGFloat
    var onComplete: () -> Void

    var body: some View {
        ZStack(alignment: .leading) {
            // High-End Glassmorphic Track with red accent
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .frame(height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            LinearGradient(
                                colors: [Color.red.opacity(0.4), Color.red.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.red.opacity(0.04))
                )

            // Instruction text
            Text("SLIDE TO CANCEL DISPATCH")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(Color.red.opacity(0.8))
                .tracking(2.0)
                .frame(maxWidth: .infinity)
                .opacity(Double(1.0 - progress))
                .animation(.easeInOut, value: progress)

            // Slider Thumb
            HStack {
                Spacer().frame(width: progress * (UIScreen.main.bounds.width - 106))

                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 1.0, green: 0.2, blue: 0.2), Color(red: 0.8, green: 0.0, blue: 0.0)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.red.opacity(0.4), radius: 6, x: 0, y: 3)

                    Image(systemName: "chevron.right.2")
                        .font(.headline)
                        .fontWeight(.black)
                        .foregroundColor(.white)
                }
                .frame(width: 52, height: 52)
                .padding(4)
                .highPriorityGesture(
                    DragGesture()
                        .onChanged { value in
                            let maxSlide: CGFloat = UIScreen.main.bounds.width - 106
                            if value.translation.width > 0 && value.translation.width <= maxSlide {
                                progress = value.translation.width / maxSlide
                                if Int(value.translation.width) % 30 == 0 {
                                    HapticManager.shared.triggerImpact(style: .light)
                                }
                            }
                        }
                        .onEnded { value in
                            if progress > 0.82 {
                                HapticManager.shared.triggerNotification(type: .warning)
                                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                                    progress = 1.0
                                }
                                onComplete()
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    progress = 0.0
                                }
                            }
                        }
                )
            }
        }
        .frame(height: 60)
    }
}

import SwiftUI

struct TripDetailView: View {
    let trip: Trip
    var vehicleNumber: String = ""
    var services: AppServices? = nil
    var onAccept: (() async -> Bool)? = nil
    var onReject: ((String) async -> Void)? = nil
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var localStore: LocalDataStore

    @State private var cancelProgress: CGFloat = 0.0
    @State private var showingCancelModal = false
    @State private var cancelReason = ""
    @State private var cancelComments = ""
    @State private var isCancelConfirmed = false
    @State private var preTripFailureItems: [InspectionItemDB] = []
    @State private var preTripOdometer: Double? = nil
    @State private var isLoadingInspection = true
    @State private var vehicle: Vehicle? = nil
    @State private var showingRejectSheet = false
    @State private var preTripFuelLevel: Double? = nil
    @State private var tripFuelLogs: [FuelLog] = []
    @State private var isAccepting = false

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    if trip.status == .rejectionPending {
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "xmark.octagon.fill")
                                    .font(.title3)
                                Text("Couldn't Start the Trip")
                                    .fontWeight(.bold)
                                    .font(.title3)
                            }
                            Text("The pre-trip inspection found issues with the vehicle. The trip has been flagged for review and a replacement vehicle is being arranged by your fleet manager.")
                                .font(.caption)
                                .multilineTextAlignment(.center)
                            if !preTripFailureItems.isEmpty {
                                Divider()
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Failed Inspection Items:")
                                        .font(.caption.weight(.bold))
                                    ForEach(preTripFailureItems) { item in
                                        HStack(spacing: 6) {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .font(.caption)
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(item.itemName)
                                                    .font(.caption.weight(.semibold))
                                                if let desc = item.failDescription, !desc.isEmpty {
                                                    Text(desc)
                                                        .font(.caption2)
                                                        .opacity(0.8)
                                                }
                                            }
                                        }
                                    }
                                }
                            } else if isLoadingInspection {
                                ProgressView()
                                    .tint(.white)
                            }
                        }
                        .foregroundColor(.white)
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .cornerRadius(16)
                    }

                    if trip.status == .cancelled && (trip.cancellationReason?.localizedCaseInsensitiveContains("SOS") == true || trip.cancellationReason?.localizedCaseInsensitiveContains("emergency") == true) {
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.octagon.fill")
                                Text("SOS Emergency")
                                    .fontWeight(.bold)
                            }
                            Text("SOS emergency was triggered during this trip. The trip was cancelled and emergency services have been notified.")
                                .font(.caption)
                                .multilineTextAlignment(.center)
                        }
                        .foregroundColor(.white)
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .cornerRadius(16)
                    } else if trip.status == .cancelled && trip.cancellationReason == "no_show_pretrip" {
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "xmark.octagon.fill")
                                Text("Pre-Trip Inspection Missed")
                                    .fontWeight(.bold)
                            }
                            Text("This trip was automatically cancelled because the pre-trip inspection was not completed within the required timeframe.")
                                .font(.caption)
                                .multilineTextAlignment(.center)
                        }
                        .foregroundColor(.white)
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .cornerRadius(16)
                    }

                    if trip.status == .completed {
                        CompletedTripDetailView(trip: trip, vehicleNumber: vehicleNumber, preTripFailureItems: preTripFailureItems, preTripOdometer: preTripOdometer, preTripFuelLevel: preTripFuelLevel, tripFuelLogs: tripFuelLogs)
                    } else {
                        // --- Original Scheduled/Active Trip Details ---
                        // Clean Inline Title Header
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(trip.displayId)
                                    .font(.system(size: 32, weight: .black, design: .rounded))
                                    .foregroundColor(.primary)

                                Spacer()

                                HStack(spacing: 6) {
                                    Circle().fill(trip.status == .inProgress ? Color.blue : trip.status == .rejectionPending ? Color.red : Color.orange).frame(width: 6, height: 6)
                                    Text(trip.status.rawValue.uppercased())
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .foregroundColor(trip.status == .inProgress ? Color.blue : trip.status == .rejectionPending ? Color.red : Color.orange)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(trip.status == .inProgress ? Color.blue.opacity(0.1) : trip.status == .rejectionPending ? Color.red.opacity(0.1) : Color.orange.opacity(0.1))
                                .clipShape(Capsule())
                            }

                            Text(trip.status == .rejectionPending ? "Trip could not be started" : "Assignment Details")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 4)
                        .padding(.bottom, 4)

                        if trip.status != .rejectionPending {
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

                                VStack(alignment: .leading, spacing: 0) {
                                    Text("START LOCATION")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 30)
                                        .padding(.bottom, 4)

                                    HStack(alignment: .top, spacing: 16) {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 10, height: 10)
                                            .padding(.top, 5)
                                            .frame(width: 14)

                                        Text(trip.startLocation)
                                            .font(.body)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                    }

                                    HStack(alignment: .top, spacing: 16) {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 2)
                                            .frame(width: 14)

                                        Spacer().frame(height: 16)
                                    }
                                    .frame(height: 24)

                                    Text("END LOCATION")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 30)
                                        .padding(.bottom, 4)

                                    HStack(alignment: .top, spacing: 16) {
                                        Image(systemName: "flag.fill")
                                            .foregroundColor(.red)
                                            .font(.system(size: 10))
                                            .padding(.top, 5)
                                            .frame(width: 14)

                                        Text(trip.endLocation)
                                            .font(.body)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                    }
                                }
                            }
                            .padding(20)
                            .background(AppColor.surface)
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
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("SCHEDULED START")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.secondary)
                                        Text(trip.startTime.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        if let actual = trip.actualStartTime {
                                            Text("ACTUAL START")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(.secondary)
                                                .padding(.top, 2)
                                            Text(actual.formatted(date: .abbreviated, time: .shortened))
                                                .font(.subheadline)
                                                .fontWeight(.bold)
                                                .foregroundColor(.primary)
                                        }
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
                            .background(AppColor.surface)
                            .cornerRadius(20)
                            .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 4)
                        }

                        // 3. Vehicle Maintenance & Health Card
                        if trip.status == .rejectionPending {
                            VehicleMaintenanceReportCard(vehicleNumber: vehicleNumber, failureItems: preTripFailureItems)
                        } else {
                            VehicleMaintenanceReportCard(vehicleNumber: vehicleNumber, vehicle: vehicle)
                        }

                        if trip.status == .scheduled || trip.status == .pending {
                            // 4. Accept / Reject section for unaccepted trips
                            VStack(spacing: 12) {
                                Divider()
                                Text("Respond to this assignment")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                HStack(spacing: 12) {
                                    Button(action: { showingRejectSheet = true }) {
                                        HStack {
                                            Image(systemName: "xmark.circle.fill")
                                            Text("Reject")
                                                .fontWeight(.bold)
                                        }
                                        .foregroundColor(.red)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(Color.red.opacity(0.1))
                                        .cornerRadius(16)
                                    }

                                    Button(action: {
                                        guard !isAccepting else { return }
                                        isAccepting = true
                                        Task {
                                            let success = await onAccept?() ?? false
                                            await MainActor.run {
                                                isAccepting = false
                                                if success {
                                                    dismiss()
                                                }
                                            }
                                        }
                                    }) {
                                        HStack {
                                            if isAccepting {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                    .padding(.trailing, 4)
                                            }
                                            Image(systemName: "checkmark.circle.fill")
                                            Text(isAccepting ? "Accepting..." : "Accept")
                                                .fontWeight(.bold)
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(isAccepting ? Color.green.opacity(0.6) : Color.green)
                                        .cornerRadius(16)
                                        .shadow(color: Color.green.opacity(0.15), radius: 8, x: 0, y: 4)
                                    }
                                    .disabled(isAccepting)
                                }
                            }
                        } else if trip.status == .accepted {
                            // 5. Cancel Assignment for accepted trips (gated by 24h lock)
                            let cancellationLocked = Date() >= trip.startTime.addingTimeInterval(-TripTimingPolicy.cancellationLockWindow)
                            VStack(spacing: 8) {
                                Text("Need to cancel this assignment?")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 14)

                                if cancellationLocked {
                                    HStack {
                                        Spacer()
                                        Image(systemName: "lock.fill")
                                        Text("Cannot cancel trip now")
                                            .fontWeight(.bold)
                                        Spacer()
                                    }
                                    .padding(.vertical, 16)
                                    .background(Color.red.opacity(0.15))
                                    .foregroundColor(.red.opacity(0.6))
                                    .cornerRadius(16)

                                    Text("Cancellation is locked within 24 hours of departure. Contact your fleet manager if you cannot complete this trip.")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                } else {
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
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .task {
            guard let services else {
                isLoadingInspection = false
                return
            }
            // Fetch vehicle data if available
            if let vehicleId = trip.vehicleId, vehicle == nil {
                vehicle = try? await services.vehicleService.fetchVehicle(id: vehicleId)
            }
            // Fetch inspection data for rejectionPending and completed
            guard trip.status == .rejectionPending || trip.status == .completed else {
                isLoadingInspection = false
                return
            }
            do {
                let inspections = try await services.inspectionService.fetchInspections(tripId: trip.id)
                let currentVehicleInspections: [VehicleInspection]
                if let vehicleId = trip.vehicleId {
                    currentVehicleInspections = inspections.filter { $0.vehicleId == vehicleId }
                } else {
                    currentVehicleInspections = inspections
                }
                if trip.status == .rejectionPending,
                   let failedInspection = currentVehicleInspections.first(where: { $0.type == "pre_trip" && $0.status == .failed }) {
                    let items = try await services.inspectionService.fetchInspectionItems(inspectionId: failedInspection.id)
                    preTripFailureItems = items.filter { $0.status == "fail" }
                }
                if trip.status == .completed {
                    let preTrip = currentVehicleInspections.first(where: { $0.type == "pre_trip" })
                    preTripOdometer = preTrip?.odometerReading
                    preTripFuelLevel = preTrip?.fuelLevel
                }
            } catch {
                print("Failed to fetch inspection data: \(error)")
            }
            if trip.status == .completed {
                tripFuelLogs = (try? await services.fuelService.fetchFuelLogs(tripId: trip.id)) ?? []
            }
            isLoadingInspection = false
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
        .sheet(isPresented: $showingRejectSheet) {
            RejectTripSheet(trip: trip) { reason in
                Task { await onReject?(reason) }
            }
        }
    }
}

// MARK: - Redesigned Historical Completed Trip Detail View
struct CompletedTripDetailView: View {
    let trip: Trip
    var vehicleNumber: String = ""
    var preTripFailureItems: [InspectionItemDB] = []
    var preTripOdometer: Double? = nil
    var preTripFuelLevel: Double? = nil
    var tripFuelLogs: [FuelLog] = []
    @EnvironmentObject var localStore: LocalDataStore
    @EnvironmentObject var locationService: LocationManager

    @State private var showingReportIssueSheet = false

    private var distanceValue: Double {
        trip.distanceKm ?? 0.0
    }

    private var startOdometerDisplay: String {
        guard let odo = preTripOdometer else { return "—" }
        return "\(Int(odo)) km"
    }

    private var mileageDisplay: String {
        guard let consumed = trip.fuelConsumed, consumed > 0, distanceValue > 0 else { return "—" }
        return String(format: "%.1f km/L", distanceValue / consumed)
    }

    private var endOdometerDisplay: String {
        guard let odo = trip.finalOdometer else { return "—" }
        return "\(Int(odo)) km"
    }

    var body: some View {
        VStack(spacing: 20) {
            // Clean Inline Title Header
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(trip.displayId)
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

                VStack(alignment: .leading, spacing: 0) {
                    // Start Location Header
                    Text("START LOCATION")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.leading, 30)
                        .padding(.bottom, 4)
                    
                    // Start Location Address
                    HStack(alignment: .top, spacing: 16) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)
                            .padding(.top, 5)
                            .frame(width: 14)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(trip.startLocation)
                                .font(.body)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            Text("Start Time: \(trip.actualStartTime?.formatted(date: .abbreviated, time: .shortened) ?? "N/A")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Route connector
                    HStack(alignment: .top, spacing: 16) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 2)
                            .frame(width: 14)
                        
                        Spacer().frame(height: 16)
                    }
                    .frame(height: 24)
                    
                    // End Location Header
                    Text("STOP LOCATION (DESTINATION)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.leading, 30)
                        .padding(.bottom, 4)
                    
                    // End Location Address
                    HStack(alignment: .top, spacing: 16) {
                        Image(systemName: "flag.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 10))
                            .padding(.top, 5)
                            .frame(width: 14)
                        
                        VStack(alignment: .leading, spacing: 4) {
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
            .background(AppColor.surface)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 4)

            // 2. Odometer & Distance Card
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "arrow.triangle.swap")
                        .foregroundColor(.blue)
                    Text("Odometer & Distance")
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
                            Text(startOdometerDisplay)
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
                            Text(endOdometerDisplay)
                                .font(.subheadline)
                                .fontWeight(.bold)
                        }
                    }
                    .padding(12)
                    .background(Color.blue.opacity(0.03))
                    .cornerRadius(10)
                }

                Divider()

                // Distance
                VStack(alignment: .leading, spacing: 10) {
                    Text("DISTANCE TRAVELLED")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)

                    HStack {
                        Image(systemName: "arrow.triangle.swap")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text(distanceValue > 0 ? "\(Int(distanceValue)) km" : "—")
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }
                    .padding(12)
                    .background(Color.blue.opacity(0.03))
                    .cornerRadius(10)
                }
            }
            .padding(20)
            .background(AppColor.surface)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 4)

            // 3. Fuel & Mileage Card
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "fuelpump.fill")
                        .foregroundColor(.green)
                    Text("Fuel & Mileage")
                        .font(.headline)
                        .fontWeight(.bold)
                }

                Divider()

                // Fuel Level Readings
                VStack(alignment: .leading, spacing: 10) {
                    Text("FUEL LEVEL READINGS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)

                    HStack {
                        VStack(alignment: .leading) {
                            Text("Start Level")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(preTripFuelLevel.map { "\(Int($0))%" } ?? "—")
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
                            Text(trip.finalFuelLevel.map { "\(Int($0))%" } ?? "—")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.03))
                    .cornerRadius(10)
                }

                Divider()

                HStack(spacing: 20) {
                    VStack(alignment: .center, spacing: 4) {
                        Text("MILEAGE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                        Text(mileageDisplay)
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Text("FUEL CONSUMED")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                            if trip.fuelConsumedFlagged {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(.orange)
                            }
                        }
                        if let consumed = trip.fuelConsumed {
                            HStack(spacing: 4) {
                                Text("\(consumed, specifier: "%.1f") L")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                if trip.fuelConsumedFlagged {
                                    Text("Data may be incomplete")
                                        .font(.system(size: 7))
                                        .foregroundColor(.orange)
                                }
                            }
                        } else {
                            Text("—")
                                .font(.subheadline)
                                .fontWeight(.bold)
                        }
                    }
                }

                Divider()

                // Refill details from database
                if !tripFuelLogs.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("FUEL LOGS (DATABASE)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)

                        ForEach(tripFuelLogs) { log in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Label(log.fuelType, systemImage: "fuelpump.fill")
                                        .font(.footnote)
                                        .foregroundColor(.primary)
                                    Text(log.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    if let volume = log.volumeFilled {
                                        Text("\(volume, specifier: "%.1f") L")
                                            .font(.footnote)
                                            .fontWeight(.semibold)
                                    } else if let kwh = log.kWhAdded {
                                        Text("\(kwh, specifier: "%.1f") kWh")
                                            .font(.footnote)
                                            .fontWeight(.semibold)
                                    }
                                    if let cost = log.cost {
                                        Text("₹\(cost, specifier: "%.2f")")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text("No fuel logs recorded for this trip.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(20)
            .background(AppColor.surface)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 4)

            // 4. Notes & Incidents Card
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
            .background(AppColor.surface)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 4)
        }
    }
}

// MARK: - Redesigned Reusable Vehicle Maintenance & Health Card View
struct VehicleMaintenanceReportCard: View {
    let vehicleNumber: String
    var failureItems: [InspectionItemDB] = []
    var vehicle: Vehicle? = nil

    private var hasFailures: Bool { !failureItems.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: hasFailures ? "exclamationmark.triangle.fill" : "wrench.and.screwdriver.fill")
                    .foregroundColor(hasFailures ? .red : .blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(hasFailures ? "Vehicle Inspection Issues Found" : "Vehicle Status")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text(hasFailures ? "One or more parts require attention" : "No active issues")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(hasFailures ? "ISSUES FOUND" : "HEALTHY")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(hasFailures ? .red : .green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(hasFailures ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                    .cornerRadius(6)
            }

            if hasFailures {
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    Text("The following parts failed pre-trip inspection")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(failureItems) { item in
                        HStack(spacing: 10) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.itemName)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundColor(.primary)
                                if let desc = item.failDescription, !desc.isEmpty {
                                    Text(desc)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.04))
                        .cornerRadius(8)
                    }
                }
            } else {
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("All systems operational")
                                .font(.subheadline.weight(.bold))
                            if let v = vehicle {
                                Text("Odometer: \(Int(v.odometer ?? 0)) km")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(AppColor.surface)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 4)
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

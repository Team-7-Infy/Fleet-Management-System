import Foundation
import Combine

@MainActor
final class TripManagementViewModel: ObservableObject {
    @Published private(set) var trips: [Trip] = []
    @Published var isLoading = false
    @Published var successMessage: String?
    @Published var errorMessage: String?
    @Published var lastTripNotificationTargetDriverId: UUID?

    private let tripService: TripServiceProtocol
    private let vehicleService: VehicleServiceProtocol
    private let userManagementService: UserManagementServiceProtocol
    private var successClearTask: Task<Void, Never>?

    init(
        tripService: TripServiceProtocol,
        vehicleService: VehicleServiceProtocol,
        userManagementService: UserManagementServiceProtocol
    ) {
        self.tripService = tripService
        self.vehicleService = vehicleService
        self.userManagementService = userManagementService
    }

    var activeTrips: [Trip] {
        trips.filter { $0.status != .completed && $0.status != .rejected && $0.status != .cancelled }
    }

    var rejectionRequests: [Trip] {
        trips.filter { $0.status == .rejectionPending }
            .sorted { $0.startTime < $1.startTime }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            trips = try await tripService.fetchTrips()
                .sorted { $0.startTime < $1.startTime }
            errorMessage = nil
        } catch is CancellationError {
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createTrip(form: FleetManagerTripForm) async -> Bool {
        lastTripNotificationTargetDriverId = nil
        guard form.isValid else {
            errorMessage = "Complete trip details. Start location, destination, and manual driver/vehicle selections must be provided."
            clearSuccessMessage()
            return false
        }

        do {
            if form.isAutoAssign {
                let initialTrip = form.makeTrip()
                let trip = try await tripService.createTrip(initialTrip)
                if let vehicleType = trip.vehicleTypeRequested, vehicleType.isEmpty == false {
                    let result = try await autoAssign(trip: trip)
                    if let (vehicleId, driverId) = result {
                        var updatedTrip = trip
                        updatedTrip.vehicleId = vehicleId
                        updatedTrip.driverId = driverId
                        let saved = try await tripService.updateTrip(updatedTrip)
                        try await vehicleService.assignDriver(vehicleId: vehicleId, driverId: driverId)
                        try await vehicleService.setVehicleStatus(vehicleId: vehicleId, status: .assigned)
                        trips.insert(saved, at: 0)
                        lastTripNotificationTargetDriverId = driverId

                        let driverName = await resolveDriverName(driverId: driverId)
                        let vehiclePlate = await resolveVehiclePlate(vehicleId: vehicleId)
                        showSuccessMessage(
                            "Trip created — automatically assigned to \(driverName) (\(vehiclePlate))."
                        )
                    } else {
                        trips.insert(trip, at: 0)
                        showSuccessMessage(
                            "Trip created — no eligible vehicle or driver was available."
                        )
                    }
                } else {
                    trips.insert(trip, at: 0)
                    showSuccessMessage("Trip created (manual assignment required).")
                }
            } else {
                if let vehicleId = form.selectedVehicleId, let driverId = form.selectedDriverId {
                    let tripEnd = form.endTime ?? form.startTime.addingTimeInterval(7200)
                    let isDriverAvail = try await isDriverAvailable(driverId: driverId, startTime: form.startTime, endTime: tripEnd, excludingTripId: nil)
                    if !isDriverAvail {
                        errorMessage = "The selected driver is already assigned to an overlapping active trip or has a schedule conflict."
                        clearSuccessMessage()
                        return false
                    }

                    let isVehAvail = try await isVehicleAvailable(vehicleId: vehicleId, startTime: form.startTime, endTime: tripEnd, excludingTripId: nil)
                    if !isVehAvail {
                        errorMessage = "The selected vehicle is already assigned to an overlapping active trip."
                        clearSuccessMessage()
                        return false
                    }
                }

                let initialTrip = form.makeTrip()
                let trip = try await tripService.createTrip(initialTrip)
                if let vehicleId = trip.vehicleId, let driverId = trip.driverId {
                    try await vehicleService.assignDriver(vehicleId: vehicleId, driverId: driverId)
                    try await vehicleService.setVehicleStatus(vehicleId: vehicleId, status: .assigned)
                    trips.insert(trip, at: 0)
                    lastTripNotificationTargetDriverId = driverId

                    let driverName = await resolveDriverName(driverId: driverId)
                    let vehiclePlate = await resolveVehiclePlate(vehicleId: vehicleId)
                    showSuccessMessage(
                        "Trip created — manually assigned to \(driverName) (\(vehiclePlate))."
                    )
                } else {
                    trips.insert(trip, at: 0)
                    showSuccessMessage("Trip created.")
                }
            }

            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            clearSuccessMessage()
            return false
        }
    }

    func updateStatus(_ trip: Trip, status: TripStatus) async {
        do {
            try await tripService.updateTripStatus(id: trip.id, status: status)

            if status == .completed, let driverId = trip.driverId {
                _ = try? await userManagementService.calculateAndUpsertDriverScore(driverId: driverId)
            }

            if (status == .completed || status == .rejected || status == .cancelled),
               let vehicleId = trip.vehicleId {
                try await vehicleService.unassignDriver(vehicleId: vehicleId)
            }

            if let index = trips.firstIndex(where: { $0.id == trip.id }) {
                trips[index].status = status
            }
            showSuccessMessage("Trip marked \(status.title.lowercased()).")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            clearSuccessMessage()
        }
    }

    func approveRejection(for trip: Trip) async {
        lastTripNotificationTargetDriverId = nil
        do {
            let rejectingDriverId = trip.driverId

            // Free up old vehicle
            if let oldVehicleId = trip.vehicleId {
                try await vehicleService.unassignDriver(vehicleId: oldVehicleId)
                try await vehicleService.setVehicleStatus(vehicleId: oldVehicleId, status: .available)
            }

            // Determine vehicle type: prefer vehicleTypeRequested, fall back to assigned vehicle
            let vehicleType: String?
            if let vt = trip.vehicleTypeRequested, vt.isEmpty == false {
                vehicleType = vt
            } else if let vid = trip.vehicleId,
                      let vehicle = try? await vehicleService.fetchVehicle(id: vid) {
                vehicleType = vehicle.vehicleType
            } else {
                vehicleType = nil
            }

            let tripEnd = trip.endTime ?? trip.startTime.addingTimeInterval(7200)

            if let vehicleType, vehicleType.isEmpty == false,
               let vehicle = try await fetchEligibleVehicles(for: vehicleType, tripStart: trip.startTime, tripEnd: tripEnd).first {
                let eligible = try await fetchEligibleDrivers(
                    for: vehicleType,
                    tripStart: trip.startTime,
                    tripEnd: tripEnd
                )
                let excludedIds = Set([rejectingDriverId].compactMap { $0 })
                let candidates = try await rankDrivers(
                    eligible.filter { excludedIds.contains($0.id) == false },
                    tripStart: trip.startTime,
                    tripEnd: tripEnd
                )

                if let bestDriver = candidates.first {
                    var updatedTrip = trip
                    updatedTrip.vehicleId = vehicle.id
                    updatedTrip.driverId = bestDriver.id
                    updatedTrip.status = .scheduled
                    updatedTrip.rejectionReason = nil

                    let saved = try await tripService.updateTrip(updatedTrip)
                    try await vehicleService.assignDriver(vehicleId: vehicle.id, driverId: bestDriver.id)
                    try await vehicleService.setVehicleStatus(vehicleId: vehicle.id, status: .assigned)
                    lastTripNotificationTargetDriverId = bestDriver.id

                    if let index = trips.firstIndex(where: { $0.id == trip.id }) {
                        trips[index] = saved
                    }

                    let driverName = await resolveDriverName(driverId: bestDriver.id)
                    let vehiclePlate = await resolveVehiclePlate(vehicleId: vehicle.id)
                    showSuccessMessage(
                        "Rejection approved — reassigned to \(driverName) (\(vehiclePlate))."
                    )
                    errorMessage = nil
                    return
                }
            }

            // No replacement found — leave trip unassigned/pending
            try await tripService.updateTripStatus(id: trip.id, status: .scheduled, rejectionReason: nil)
            if let index = trips.firstIndex(where: { $0.id == trip.id }) {
                trips[index].status = .scheduled
                trips[index].vehicleId = nil
                trips[index].driverId = nil
                trips[index].rejectionReason = nil
            }
            showSuccessMessage(
                "Rejection approved — no eligible replacement available. Trip left unassigned."
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            clearSuccessMessage()
        }
    }

    func denyRejection(for trip: Trip) async {
        lastTripNotificationTargetDriverId = trip.driverId
        do {
            try await tripService.updateTripStatus(id: trip.id, status: .scheduled, rejectionReason: nil)
            if let index = trips.firstIndex(where: { $0.id == trip.id }) {
                trips[index].status = .scheduled
                trips[index].rejectionReason = nil
            }
            showSuccessMessage("Rejection denied, trip returned to scheduled.")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            clearSuccessMessage()
        }
    }

    func delete(_ trip: Trip) async {
        do {
            try await tripService.deleteTrip(id: trip.id)
            trips.removeAll { $0.id == trip.id }
            if let vehicleId = trip.vehicleId {
                try await vehicleService.unassignDriver(vehicleId: vehicleId)
            }
            showSuccessMessage("Trip deleted.")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            clearSuccessMessage()
        }
    }

    func trip(for id: UUID?) -> Trip? {
        guard let id else { return nil }
        return trips.first { $0.id == id }
    }

    func fetchTelemetry(driverId: UUID) async throws -> Telemetry? {
        return try await tripService.fetchTelemetry(driverId: driverId).first
    }

    // MARK: - Auto Assignment

    private func autoAssign(trip: Trip) async throws -> (vehicleId: UUID, driverId: UUID)? {
        guard let vehicleType = trip.vehicleTypeRequested else { return nil }
        let tripEnd = trip.endTime ?? trip.startTime.addingTimeInterval(7200)

        let eligibleVehicles = try await fetchEligibleVehicles(for: vehicleType, tripStart: trip.startTime, tripEnd: tripEnd)
        guard let vehicle = eligibleVehicles.first else { return nil }

        let eligibleDrivers = try await fetchEligibleDrivers(for: vehicleType, tripStart: trip.startTime, tripEnd: tripEnd)
        guard let driver = try await rankDrivers(eligibleDrivers, tripStart: trip.startTime, tripEnd: tripEnd).first else {
            return nil
        }

        return (vehicle.id, driver.id)
    }

    private func checkVehicleIdleViolation(vehicle: Vehicle, trips: [Trip], tasks: [MaintenanceTask], targetStartTime: Date) -> Bool {
        let vehicleTrips = trips.filter { $0.vehicleId == vehicle.id && $0.status == .completed }
        let sortedTrips = vehicleTrips.sorted(by: { $0.startTime < $1.startTime })

        let addedDate = vehicle.addedToFleetAt ?? targetStartTime.addingTimeInterval(-45 * 24 * 3600)

        struct Gap {
            let start: Date
            let end: Date
        }
        var gaps: [Gap] = []

        if sortedTrips.isEmpty {
            gaps.append(Gap(start: addedDate, end: targetStartTime))
        } else {
            gaps.append(Gap(start: addedDate, end: sortedTrips[0].startTime))
            for i in 0..<(sortedTrips.count - 1) {
                let tripEnd = sortedTrips[i].endTime ?? sortedTrips[i].startTime.addingTimeInterval(7200)
                let nextTripStart = sortedTrips[i+1].startTime
                if nextTripStart > tripEnd {
                    gaps.append(Gap(start: tripEnd, end: nextTripStart))
                }
            }
            let lastTripEnd = sortedTrips.last!.endTime ?? sortedTrips.last!.startTime.addingTimeInterval(7200)
            if targetStartTime > lastTripEnd {
                gaps.append(Gap(start: lastTripEnd, end: targetStartTime))
            }
        }

        let oneMonth: TimeInterval = 30 * 24 * 3600
        for gap in gaps {
            let gapDuration = gap.end.timeIntervalSince(gap.start)
            if gapDuration > oneMonth {
                let hasMaintenance = tasks.contains { task in
                    guard task.status == .completed, let compAt = task.completedAt else { return false }
                    return compAt >= gap.start && compAt <= gap.end
                }
                if !hasMaintenance {
                    return true
                }
            }
        }
        return false
    }

    private func fetchEligibleVehicles(for vehicleType: String, tripStart: Date, tripEnd: Date) async throws -> [Vehicle] {
        let all = try await vehicleService.fetchVehicles()
        let allTrips = try await tripService.fetchTrips()
        let completedTasks = (try? await vehicleService.fetchCompletedMaintenanceTasks()) ?? []
        let taskVehicles = (try? await vehicleService.fetchTaskVehicles()) ?? []

        let taskIdsByVehicle = Dictionary(grouping: taskVehicles, by: \.vin)

        var eligible: [Vehicle] = []
        for vehicle in all {
            guard (vehicle.status == .available || vehicle.status == .assigned),
                  vehicle.vehicleType.lowercased() == vehicleType.lowercased()
            else { continue }

            let vehicleTrips = allTrips.filter { $0.vehicleId == vehicle.id }
            guard hasNoOverlap(vehicleTrips, tripStart: tripStart, tripEnd: tripEnd) else { continue }

            let completedTrips = vehicleTrips.filter { $0.status == .completed }
            if let mostRecentCompleted = completedTrips.sorted(by: { $0.startTime > $1.startTime }).first {
                let hasInspection = try await tripService.hasPostTripInspection(tripId: mostRecentCompleted.id)
                if !hasInspection {
                    continue
                }
            }

            let vehicleTaskIds = Set((taskIdsByVehicle[vehicle.id] ?? []).map(\.taskId))
            let vehicleTasks = completedTasks.filter { vehicleTaskIds.contains($0.id) }

            if checkVehicleIdleViolation(vehicle: vehicle, trips: allTrips, tasks: vehicleTasks, targetStartTime: tripStart) {
                continue
            }

            eligible.append(vehicle)
        }
        return eligible
    }

    private func fetchEligibleDrivers(for vehicleType: String, tripStart: Date, tripEnd: Date) async throws -> [Driver] {
        let allDrivers = try await userManagementService.fetchDrivers()
        let allUsers = try await userManagementService.fetchUsers()
        let allActiveTrips = try await tripService.fetchTrips()

        // Fetch ONLY schedules overlapping this trip window
        let activeSchedules = try await userManagementService.fetchDriverSchedules(
            overlappingStart: tripStart,
            overlappingEnd: tripEnd
        )

        let activeUserIds = Set(allUsers.filter { $0.isActive && $0.deletedAt == nil }.map(\.id))

        // O(1) Pre-grouping lookup optimization
        let schedulesByDriver = Dictionary(grouping: activeSchedules, by: \.driverId)

        return allDrivers.filter { driver in
            guard driver.status != .unavailable && driver.status != .inactive,
                  driver.vehicleType.lowercased() == vehicleType.lowercased(),
                  activeUserIds.contains(driver.userId)
            else { return false }

            // 1. Verify no existing overlapping trips for the driver
            let driverTrips = allActiveTrips.filter { $0.driverId == driver.id }
            guard hasNoOverlap(driverTrips, tripStart: tripStart, tripEnd: tripEnd) else { return false }

            // 2. Verify no schedule blockouts (where isAvailable is explicitly set to false)
            let driverSchedules = schedulesByDriver[driver.id] ?? []
            guard hasNoScheduleConflict(driverSchedules, tripStart: tripStart, tripEnd: tripEnd) else { return false }

            return true
        }
    }

    func hasNoOverlap(_ existing: [Trip], tripStart: Date, tripEnd: Date) -> Bool {
        let overlappingStatuses: Set<TripStatus> = [.scheduled, .pending, .accepted, .inProgress]
        for t in existing {
            if overlappingStatuses.contains(t.status) {
                let tEnd = t.endTime ?? t.startTime.addingTimeInterval(7200)
                if t.startTime < tripEnd && tEnd > tripStart {
                    return false
                }
            } else if t.status == .completed {
                let tEnd = t.endTime ?? t.startTime.addingTimeInterval(7200)

                if tripStart >= t.startTime {
                    let bufferEnd = tEnd.addingTimeInterval(5 * 3600)
                    if tripStart < bufferEnd {
                        return false
                    }
                } else {
                    let bufferStart = t.startTime.addingTimeInterval(-5 * 3600)
                    if tripEnd > bufferStart {
                        return false
                    }
                }
            }
        }
        return true
    }

    private func hasNoScheduleConflict(_ schedules: [DriverSchedule], tripStart: Date, tripEnd: Date) -> Bool {
        for s in schedules {
            // If driver is explicitly marked unavailable and the blocks overlap, exclude
            if !s.isAvailable && s.startTime < tripEnd && s.endTime > tripStart {
                return false
            }
        }
        return true
    }

    private func rankDrivers(_ drivers: [Driver], tripStart: Date, tripEnd: Date) async throws -> [Driver] {
        struct Candidate {
            let driver: Driver
            let score: Double
        }

        var candidates: [Candidate] = []
        for driver in drivers {
            let driverScore = (try? await userManagementService.fetchDriverScore(driverId: driver.id))?.overallScore ?? 0
            let activeCount = trips.filter { $0.driverId == driver.id && activeWorkStatuses.contains($0.status) }.count

            let normalizedScore = driverScore / 100.0
            let workloadScore = 1.0 / Double(activeCount + 1)

            let composite = normalizedScore * 0.60 + workloadScore * 0.40

            candidates.append(Candidate(driver: driver, score: composite))
        }

        return candidates.sorted { $0.score > $1.score }.map(\.driver)
    }

    func isDriverAvailable(driverId: UUID, startTime: Date, endTime: Date?, excludingTripId: UUID?) async throws -> Bool {
        let allActiveTrips = try await tripService.fetchTrips()
        let tripEnd = endTime ?? startTime.addingTimeInterval(7200)

        // Check if the driver has an overlapping active trip
        let hasTripOverlap = allActiveTrips.contains { trip in
            guard trip.driverId == driverId,
                  trip.id != excludingTripId,
                  activeWorkStatuses.contains(trip.status)
            else { return false }

            let tEnd = trip.endTime ?? trip.startTime.addingTimeInterval(7200)
            return trip.startTime < tripEnd && tEnd > startTime
        }

        if hasTripOverlap { return false }

        // Check if they are blocked out by their schedule
        let activeSchedules = try await userManagementService.fetchDriverSchedules(
            overlappingStart: startTime,
            overlappingEnd: tripEnd
        )
        let hasBlockedSchedule = activeSchedules.contains { s in
            s.driverId == driverId && !s.isAvailable && s.startTime < tripEnd && s.endTime > startTime
        }

        return !hasBlockedSchedule
    }

    func isVehicleAvailable(vehicleId: UUID, startTime: Date, endTime: Date?, excludingTripId: UUID?) async throws -> Bool {
        let allActiveTrips = try await tripService.fetchTrips()
        let tripEnd = endTime ?? startTime.addingTimeInterval(7200)

        // Check if the vehicle has an overlapping active trip
        let hasTripOverlap = allActiveTrips.contains { trip in
            guard trip.vehicleId == vehicleId,
                  trip.id != excludingTripId,
                  activeWorkStatuses.contains(trip.status)
            else { return false }

            let tEnd = trip.endTime ?? trip.startTime.addingTimeInterval(7200)
            return trip.startTime < tripEnd && tEnd > startTime
        }

        return !hasTripOverlap
    }

    private var activeWorkStatuses: Set<TripStatus> {
        [.scheduled, .pending, .accepted, .inProgress]
    }

    private func resolveDriverName(driverId: UUID) async -> String {
        let drivers = (try? await userManagementService.fetchDrivers()) ?? []
        guard let driver = drivers.first(where: { $0.id == driverId }) else { return "Unknown" }
        let users = (try? await userManagementService.fetchUsers()) ?? []
        guard let user = users.first(where: { $0.id == driver.userId }) else { return "Unknown" }
        return user.displayName
    }

    private func resolveVehiclePlate(vehicleId: UUID) async -> String {
        guard let vehicle = try? await vehicleService.fetchVehicle(id: vehicleId) else { return "Unknown" }
        return vehicle.formattedLicencePlate
    }

    // MARK: - Helpers

    private func showSuccessMessage(_ message: String) {
        successMessage = message
        successClearTask?.cancel()
        successClearTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard Task.isCancelled == false else { return }
            await MainActor.run {
                guard self?.successMessage == message else { return }
                self?.successMessage = nil
            }
        }
    }

    private func clearSuccessMessage() {
        successClearTask?.cancel()
        successMessage = nil
    }
}

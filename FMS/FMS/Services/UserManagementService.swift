import Foundation
import Supabase



final actor UserManagementService: UserManagementServiceProtocol {
    private let supabase: SupabaseServiceProtocol

    init(supabase: SupabaseServiceProtocol) {
        self.supabase = supabase
    }

    func fetchUsers() async throws -> [User] {
        try await supabase.client
            .from("users")
            .select()
            .is("deleted_at", value: nil)
            .order("createdat", ascending: false)
            .execute()
            .value
    }

    func createUser(_ user: User) async throws -> User {
        try await supabase.client
            .from("users")
            .insert(user, returning: .representation)
            .select()
            .single()
            .execute()
            .value
    }

    func updateUser(_ user: User) async throws -> User {
        let update: [String: AnyJSON] = [
            "email": .string(user.email),
            "aadhar": .string(user.aadhar),
            "contact": .integer(Int(user.contact)),
            "f_name": .string(user.fName),
            "l_name": .string(user.lName),
            "address": .string(user.address),
            "avatarurl": user.avatarUrl.map { .string($0) } ?? .null,
        ]

        try await supabase.client
            .from("users")
            .update(update)
            .eq("userid", value: user.id.uuidString)
            .execute()

        let updatedUser: User = try await supabase.client
            .from("users")
            .select()
            .eq("userid", value: user.id.uuidString)
            .single()
            .execute()
            .value

        return updatedUser
    }

    func deleteDriverByUserId(id: UUID) async throws {
        // Soft-delete only — role rows are preserved for historical reference.
        // Driver associations (trips, vehicles) are unlinked on user soft-delete.
    }

    func deleteMaintenancePersonnelByUserId(id: UUID) async throws {
        // Soft-delete only — role rows preserved for historical reference.
    }

    func deleteFleetManagerByUserId(id: UUID) async throws {
        // Soft-delete only — role rows preserved for historical reference.
    }

    func deleteUser(id: UUID) async throws {
        let now = ISO8601DateFormatter().string(from: Date())
        try await supabase.client
            .from("users")
            .update(["deleted_at": AnyJSON.string(now), "isactive": AnyJSON.bool(false)])
            .eq("userid", value: id.uuidString)
            .execute()
    }

    func fetchDrivers() async throws -> [Driver] {
        try await supabase.client
            .from("drivers")
            .select()
            .execute()
            .value
    }

    func createDriver(_ driver: Driver) async throws -> Driver {
        try await supabase.client
            .from("drivers")
            .insert(driver, returning: .representation)
            .select()
            .single()
            .execute()
            .value
    }

    func updateDriverProfile(userId: UUID, licenceNumber: String, vehicleType: String) async throws {
        let update: [String: AnyJSON] = [
            "licencenum": .string(licenceNumber.trimmingCharacters(in: .whitespacesAndNewlines)),
            "vehicletype": .string(vehicleType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        ]

        try await supabase.client
            .from("drivers")
            .update(update)
            .eq("userid", value: userId.uuidString)
            .execute()
    }

    func fetchMaintenancePersonnel() async throws -> [MaintenancePersonnel] {
        try await supabase.client
            .from("maintenance_personnel")
            .select()
            .execute()
            .value
    }

    func createMaintenancePersonnel(_ personnel: MaintenancePersonnel) async throws -> MaintenancePersonnel {
        try await supabase.client
            .from("maintenance_personnel")
            .insert(personnel, returning: .representation)
            .select()
            .single()
            .execute()
            .value
    }

    func fetchFleetManagers() async throws -> [FleetManager] {
        try await supabase.client
            .from("fleet_manager")
            .select()
            .execute()
            .value
    }

    func createFleetManager(_ manager: FleetManager) async throws -> FleetManager {
        try await supabase.client
            .from("fleet_manager")
            .insert(manager, returning: .representation)
            .select()
            .single()
            .execute()
            .value
    }

    func fetchAllDriverScores() async throws -> [DriverScore] {
        try await supabase.client
            .from("driver_scores")
            .select()
            .execute()
            .value
    }

    func upsertDriverScore(_ score: DriverScore) async throws -> DriverScore {
        if let existing = try? await supabase.client
            .from("driver_scores")
            .select()
            .eq("driver_id", value: score.driverId.uuidString)
            .single()
            .execute()
            .value as DriverScore? {
            let update: [String: AnyJSON] = [
                "overall_score": .double(score.overallScore),
                "inspection_false_rate": score.inspectionFalseRate.map { .double($0) } ?? .null,
                "geofence_violation_rate": score.geofenceViolationRate.map { .double($0) } ?? .null,
                "compliance_violation_rate": score.complianceViolationRate.map { .double($0) } ?? .null,
                "mileage_accuracy": score.mileageAccuracy.map { .double($0) } ?? .null,
                "calculated_at": .string(ISO8601DateFormatter().string(from: Date()))
            ]
            try await supabase.client
                .from("driver_scores")
                .update(update)
                .eq("driver_id", value: score.driverId.uuidString)
                .execute()

            return try await supabase.client
                .from("driver_scores")
                .select()
                .eq("driver_id", value: score.driverId.uuidString)
                .single()
                .execute()
                .value
        } else {
            return try await supabase.client
                .from("driver_scores")
                .insert(score, returning: .representation)
                .select()
                .single()
                .execute()
                .value
        }
    }

    func calculateAndUpsertDriverScore(driverId: UUID) async throws -> DriverScore {
        let completedTrips: [Trip] = try await supabase.client
            .from("trips")
            .select()
            .eq("driverid", value: driverId.uuidString)
            .eq("status", value: "completed")
            .execute()
            .value

        let totalTrips = completedTrips.count

        // Factor 1: Inspection False Rate
        let inspections: [VehicleInspection] = try await supabase.client
            .from("vehicle_inspections")
            .select()
            .eq("driver_id", value: driverId.uuidString)
            .execute()
            .value

        let totalInspections = inspections.count
        let failedInspections = inspections.filter { $0.status == .failed }.count
        let inspectionRate = totalInspections > 0 ? Double(failedInspections) / Double(totalInspections) : 0.0
        let inspectionScore = totalInspections > 0 ? max(0, (1.0 - inspectionRate) * 100) : 75.0

        // Factor 2: Geofence Violation Rate
        let tripIds = completedTrips.map(\.id.uuidString)
        var deviationAlertsCount = 0
        if !tripIds.isEmpty {
            let alerts: [DeviationAlert] = (try? await supabase.client
                .from("deviation_alert")
                .select()
                .in("tripid", values: tripIds)
                .execute()
                .value) ?? []
            deviationAlertsCount = alerts.count
        }
        let violationRate = totalTrips > 0 ? Double(deviationAlertsCount) / Double(max(totalTrips, 1)) : 0.0
        let geofenceScore = totalTrips > 0 ? max(0, (1.0 - min(violationRate, 1.0)) * 100) : 75.0

        // Factor 3: Compliance / Schedule Adherence
        let onTimeCount = completedTrips.filter { trip in
            guard let end = trip.endTime else { return false }
            let expectedDuration: TimeInterval = 8 * 3600
            return end <= trip.startTime.addingTimeInterval(expectedDuration)
        }.count
        let complianceScore = totalTrips > 0 ? Double(onTimeCount) / Double(totalTrips) * 100 : 75.0

        // Factor 4: Mileage Accuracy
        let distances = completedTrips.compactMap(\.distanceKm).filter { $0 > 0 }
        let mileageScore: Double
        if distances.count >= 3 {
            let mean = distances.reduce(0, +) / Double(distances.count)
            let variance = distances.map { pow($0 - mean, 2) }.reduce(0, +) / Double(distances.count - 1)
            let cv = sqrt(variance) / mean
            mileageScore = max(0, min(100, 100 - cv * 50))
        } else {
            mileageScore = 75.0
        }

        let overall = (inspectionScore + geofenceScore + complianceScore + mileageScore) / 4.0

        let score = DriverScore(
            id: UUID(),
            driverId: driverId,
            overallScore: overall.rounded(),
            inspectionFalseRate: (inspectionScore * 100).rounded() / 100,
            geofenceViolationRate: (geofenceScore * 100).rounded() / 100,
            complianceViolationRate: (complianceScore * 100).rounded() / 100,
            mileageAccuracy: (mileageScore * 100).rounded() / 100,
            calculatedAt: Date()
        )

        return try await upsertDriverScore(score)
    }

    func fetchDriverScore(driverId: UUID) async throws -> DriverScore? {
        try? await supabase.client
            .from("driver_scores")
            .select()
            .eq("driver_id", value: driverId.uuidString)
            .single()
            .execute()
            .value
    }

    func fetchDriverSchedules(driverId: UUID) async throws -> [DriverSchedule] {
        try await supabase.client
            .from("driver_schedules")
            .select()
            .eq("driver_id", value: driverId.uuidString)
            .order("start_time", ascending: true)
            .execute()
            .value
    }

    func fetchDriverSchedules(overlappingStart: Date, overlappingEnd: Date) async throws -> [DriverSchedule] {
        try await supabase.client
            .from("driver_schedules")
            .select()
            .lt("start_time", value: overlappingEnd)
            .gt("end_time", value: overlappingStart)
            .execute()
            .value
    }

    func createDriverSchedule(_ schedule: DriverSchedule) async throws -> DriverSchedule {
        try await supabase.client
            .from("driver_schedules")
            .insert(schedule, returning: .representation)
            .select()
            .single()
            .execute()
            .value
    }

    func deleteDriverSchedule(id: UUID) async throws {
        try await supabase.client
            .from("driver_schedules")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    func updateDriverStatus(driverId: UUID, status: String) async throws {
        try await supabase.client
            .from("drivers")
            .update(["status": AnyJSON.string(status)])
            .eq("driverid", value: driverId.uuidString)
            .execute()
    }

    func bulkUpdateDriverStatuses(updates: [(driverId: UUID, status: String)]) async throws {
        guard !updates.isEmpty else { return }
        let grouped = Dictionary(grouping: updates) { $0.status }
        for (status, items) in grouped {
            let ids = items.map { $0.driverId.uuidString }
            try await supabase.client
                .from("drivers")
                .update(["status": AnyJSON.string(status)])
                .in("driverid", values: ids)
                .execute()
        }
    }

    func updateMaintenancePersonnelStatus(personnelId: UUID, status: String) async throws {
        try await supabase.client
            .from("maintenance_personnel")
            .update(["status": AnyJSON.string(status)])
            .eq("personnelid", value: personnelId.uuidString)
            .execute()
    }

    func bulkUpdateMaintenancePersonnelStatuses(updates: [(personnelId: UUID, status: String)]) async throws {
        guard !updates.isEmpty else { return }
        let grouped = Dictionary(grouping: updates) { $0.status }
        for (status, items) in grouped {
            let ids = items.map { $0.personnelId.uuidString }
            try await supabase.client
                .from("maintenance_personnel")
                .update(["status": AnyJSON.string(status)])
                .in("personnelid", values: ids)
                .execute()
        }
    }
}

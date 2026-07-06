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

    func fetchDriverSchedules(driverId: UUID) async throws -> [DriverSchedule] {
        try await supabase.client
            .from("driver_schedules")
            .select()
            .eq("driver_id", value: driverId.uuidString)
            .order("start_time", ascending: true)
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
}

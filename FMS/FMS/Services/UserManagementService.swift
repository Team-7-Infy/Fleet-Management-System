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
        let driver: Driver? = try? await supabase.client
            .from("drivers")
            .select()
            .eq("userid", value: id.uuidString)
            .single()
            .execute()
            .value

        if let driverId = driver?.id {
            try await supabase.client
                .from("trips")
                .update(["driverid": AnyJSON.null])
                .eq("driverid", value: driverId.uuidString)
                .execute()

            try await supabase.client
                .from("vehicles")
                .update(["driverid": AnyJSON.null])
                .eq("driverid", value: driverId.uuidString)
                .execute()

            try await supabase.client
                .from("telemetry_log")
                .delete()
                .eq("driverid", value: driverId.uuidString)
                .execute()
        }

        try await supabase.client
            .from("drivers")
            .delete()
            .eq("userid", value: id.uuidString)
            .execute()
    }

    func deleteMaintenancePersonnelByUserId(id: UUID) async throws {
        let personnel: MaintenancePersonnel? = try? await supabase.client
            .from("maintenance_personnel")
            .select()
            .eq("userid", value: id.uuidString)
            .single()
            .execute()
            .value

        if let personnelId = personnel?.id {
            try await supabase.client
                .from("maintenance_task")
                .update(["executedby": AnyJSON.null])
                .eq("executedby", value: personnelId.uuidString)
                .execute()
        }

        try await supabase.client
            .from("maintenance_personnel")
            .delete()
            .eq("userid", value: id.uuidString)
            .execute()
    }

    func deleteFleetManagerByUserId(id: UUID) async throws {
        let manager: FleetManager? = try? await supabase.client
            .from("fleet_manager")
            .select()
            .eq("userid", value: id.uuidString)
            .single()
            .execute()
            .value

        if let managerId = manager?.id {
            try await supabase.client
                .from("maintenance_task")
                .update(["scheduledby": AnyJSON.null])
                .eq("scheduledby", value: managerId.uuidString)
                .execute()
        }

        try await supabase.client
            .from("fleet_manager")
            .delete()
            .eq("userid", value: id.uuidString)
            .execute()
    }

    func deleteUser(id: UUID) async throws {
        try await supabase.client
            .from("users")
            .delete()
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
}

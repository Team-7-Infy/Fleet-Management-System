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
        try await supabase.client
            .from("users")
            .update(user, returning: .representation)
            .eq("userid", value: user.id.uuidString)
            .select()
            .single()
            .execute()
            .value
    }

    func setUserActive(id: UUID, isActive: Bool) async throws {
        try await supabase.client
            .from("users")
            .update(["isactive": isActive])
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
}

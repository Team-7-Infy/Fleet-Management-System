import Foundation
import Supabase



final actor VehicleService: VehicleServiceProtocol {
    private let supabase: SupabaseServiceProtocol

    init(supabase: SupabaseServiceProtocol) {
        self.supabase = supabase
    }

    func fetchVehicles() async throws -> [Vehicle] {
        try await supabase.client
            .from("vehicles")
            .select()
            .execute()
            .value
    }

    func fetchVehicles(forDriverId driverId: UUID) async throws -> [Vehicle] {
        try await supabase.client
            .from("vehicles")
            .select()
            .eq("driverid", value: driverId.uuidString)
            .execute()
            .value
    }

    func fetchVehicle(id: UUID) async throws -> Vehicle {
        try await supabase.client
            .from("vehicles")
            .select()
            .eq("vin", value: id.uuidString)
            .single()
            .execute()
            .value
    }

    func createVehicle(_ vehicle: Vehicle) async throws -> Vehicle {
        try await supabase.client
            .from("vehicles")
            .insert(vehicle, returning: .representation)
            .select()
            .single()
            .execute()
            .value
    }

    func updateVehicle(_ vehicle: Vehicle) async throws -> Vehicle {
        try await supabase.client
            .from("vehicles")
            .update(vehicle, returning: .representation)
            .eq("vin", value: vehicle.id.uuidString)
            .select()
            .single()
            .execute()
            .value
    }

    func deleteVehicle(id: UUID) async throws {
        try await supabase.client
            .from("vehicles")
            .delete()
            .eq("vin", value: id.uuidString)
            .execute()
    }

    func assignDriver(vehicleId: UUID, driverId: UUID) async throws {
        try await supabase.client
            .from("vehicles")
            .update(["driverid": driverId.uuidString])
            .eq("vin", value: vehicleId.uuidString)
            .execute()
    }

    func unassignDriver(vehicleId: UUID) async throws {
        let params: [String: AnyJSON] = ["driverid": .null]
        try await supabase.client
            .from("vehicles")
            .update(params)
            .eq("vin", value: vehicleId.uuidString)
            .execute()
    }
}

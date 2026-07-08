import Foundation
import Supabase

final class SupabaseVehicleService: VehicleServicing {
    private let client: SupabaseClient
    
    init(client: SupabaseClient) {
        self.client = client
    }
    
    func allVehicles() async throws -> [Vehicle] {
        let vehicles: [Vehicle] = try await client
            .from("vehicles")
            .select()
            .execute()
            .value
        return vehicles
    }
    
    func vehiclesNeedingAttention() async throws -> [Vehicle] {
        let vehicles: [Vehicle] = try await client
            .from("vehicles")
            .select()
            .execute()
            .value
        return vehicles.filter { $0.status != .available }
    }
    
    func vehicle(id: Vehicle.ID) async throws -> Vehicle {
        let vehicles: [Vehicle] = try await client
            .from("vehicles")
            .select()
            .eq("vin", value: id.uuidString)
            .execute()
            .value
        guard let vehicle = vehicles.first else {
            throw AppError.notFound("Vehicle")
        }
        return vehicle
    }
}

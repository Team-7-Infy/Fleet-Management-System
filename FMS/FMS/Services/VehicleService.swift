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
            .is("deleted_at", value: nil)
            .execute()
            .value
    }

    func fetchVehicles(forDriverId driverId: UUID) async throws -> [Vehicle] {
        try await supabase.client
            .from("vehicles")
            .select()
            .eq("driverid", value: driverId.uuidString)
            .is("deleted_at", value: nil)
            .execute()
            .value
    }

    func fetchVehicle(id: UUID) async throws -> Vehicle {
        try await supabase.client
            .from("vehicles")
            .select()
            .eq("vin", value: id.uuidString)
            .is("deleted_at", value: nil)
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
            .update(["deleted_at": AnyJSON.string(ISO8601DateFormatter().string(from: Date()))])
            .eq("vin", value: id.uuidString)
            .execute()
    }

    func setOutOfService(vehicleId: UUID) async throws {
        try await supabase.client
            .from("vehicles")
            .update(["status": AnyJSON.string(VehicleStatus.outOfService.rawValue)])
            .eq("vin", value: vehicleId.uuidString)
            .execute()
    }

    func setVehicleStatus(vehicleId: UUID, status: VehicleStatus) async throws {
        try await supabase.client
            .from("vehicles")
            .update(["status": AnyJSON.string(status.rawValue)])
            .eq("vin", value: vehicleId.uuidString)
            .execute()
    }

    func fetchVehicleDocuments(vehicleId: UUID) async throws -> [VehicleDocument] {
        try await supabase.client
            .from("vehicle_documents")
            .select()
            .eq("vehicle_id", value: vehicleId.uuidString)
            .is("deleted_at", value: nil)
            .execute()
            .value
    }

    func createVehicleDocument(_ document: VehicleDocument) async throws -> VehicleDocument {
        try await supabase.client
            .from("vehicle_documents")
            .insert(document, returning: .representation)
            .select()
            .single()
            .execute()
            .value
    }

    func updateVehicleDocument(_ document: VehicleDocument) async throws -> VehicleDocument {
        try await supabase.client
            .from("vehicle_documents")
            .update(document, returning: .representation)
            .eq("id", value: document.id.uuidString)
            .select()
            .single()
            .execute()
            .value
    }

    func deleteVehicleDocument(id: UUID) async throws {
        try await supabase.client
            .from("vehicle_documents")
            .update(["deleted_at": AnyJSON.string(ISO8601DateFormatter().string(from: Date()))])
            .eq("id", value: id.uuidString)
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

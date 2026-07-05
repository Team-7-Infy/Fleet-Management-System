import Foundation
import Supabase

final class SupabaseVehicleService: VehicleServicing {
    private let apiClient: APIClient
    
    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }
    
    func allVehicles() async throws -> [Vehicle] {
        let endpoint = APIEndpoint(path: "/rest/v1/vehicles?select=*", method: .get)
        let vehicles: [Vehicle] = try await apiClient.request(endpoint)
        return vehicles
    }
    
    func vehiclesNeedingAttention() async throws -> [Vehicle] {
        let endpoint = APIEndpoint(path: "/rest/v1/vehicles?select=*", method: .get)
        let vehicles: [Vehicle] = try await apiClient.request(endpoint)
        return vehicles.filter { $0.status != .active }
    }
    
    func vehicle(id: Vehicle.ID) async throws -> Vehicle {
        let endpoint = APIEndpoint(path: "/rest/v1/vehicles?vin=eq.\(id)&select=*", method: .get)
        let vehicles: [Vehicle] = try await apiClient.request(endpoint)
        guard let vehicle = vehicles.first else {
            throw AppError.notFound("Vehicle")
        }
        return vehicle
    }
}

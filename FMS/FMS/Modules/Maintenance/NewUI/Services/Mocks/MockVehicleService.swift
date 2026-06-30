import Foundation

struct MockVehicleService: VehicleServicing {
    func vehiclesNeedingAttention() async throws -> [Vehicle] {
        PreviewData.vehicles
    }

    func vehicle(id: Vehicle.ID) async throws -> Vehicle {
        guard let vehicle = PreviewData.vehicles.first(where: { $0.id == id }) else {
            throw AppError.notFound("Vehicle")
        }
        return vehicle
    }
}

final class SupabaseVehicleService: VehicleServicing {
    private let apiClient: APIClient
    
    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
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

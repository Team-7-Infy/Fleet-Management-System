import Foundation

struct MockVehicleService: VehicleServicing {
    func allVehicles() async throws -> [Vehicle] {
        PreviewData.vehicles
    }

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

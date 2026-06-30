import Foundation

protocol VehicleServicing {
    func vehiclesNeedingAttention() async throws -> [Vehicle]
    func vehicle(id: Vehicle.ID) async throws -> Vehicle
}

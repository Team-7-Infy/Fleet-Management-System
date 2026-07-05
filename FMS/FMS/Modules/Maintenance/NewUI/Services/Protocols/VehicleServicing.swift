import Foundation

protocol VehicleServicing {
    func allVehicles() async throws -> [Vehicle]
    func vehiclesNeedingAttention() async throws -> [Vehicle]
    func vehicle(id: Vehicle.ID) async throws -> Vehicle
}

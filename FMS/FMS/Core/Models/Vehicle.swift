import Foundation

struct Vehicle: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var make: String
    var model: String
    var year: Int
    var licencePlate: String
    var status: VehicleStatus
    var vehicleType: String
    var driverId: UUID?

    enum CodingKeys: String, CodingKey {
        case id = "vin"
        case make
        case model
        case year
        case licencePlate = "licence_plate"
        case status
        case vehicleType = "vehicletype"
        case driverId = "driverid"
    }
}

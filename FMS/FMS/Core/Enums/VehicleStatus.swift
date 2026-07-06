import Foundation

enum VehicleStatus: String, Codable, CaseIterable {
    case available = "available"
    case assigned = "assigned"
    case inMaintenance = "in_maintenance"
    case outOfService = "out_of_service"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let value = VehicleStatus(rawValue: rawValue.lowercased()) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown vehicle status: \(rawValue)"
            )
        }
        self = value
    }
}

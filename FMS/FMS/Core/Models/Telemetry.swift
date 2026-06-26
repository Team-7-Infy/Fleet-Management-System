import Foundation

struct Telemetry: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var timestamp: Date
    var speed: Double?
    var driverId: UUID
    var latitude: Double
    var longitude: Double

    enum CodingKeys: String, CodingKey {
        case id = "telemetryid"
        case timestamp
        case speed
        case driverId = "driverid"
        case latitude
        case longitude
    }
}

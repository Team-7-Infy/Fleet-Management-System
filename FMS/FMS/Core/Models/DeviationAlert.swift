import Foundation

struct DeviationAlert: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var timestamp: Date
    var distance: Double
    var vehicleId: UUID
    var geofenceId: UUID?
    var tripId: UUID?

    enum CodingKeys: String, CodingKey {
        case id = "deviationid"
        case timestamp
        case distance
        case vehicleId = "vehicleid"
        case geofenceId = "geofenceid"
        case tripId = "tripid"
    }
}

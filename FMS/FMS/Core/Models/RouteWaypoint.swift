import Foundation

struct RouteWaypoint: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var tripId: UUID
    var latitude: Double
    var longitude: Double
    var bufferRadius: Double
    var sequenceOrder: Int

    enum CodingKeys: String, CodingKey {
        case id = "waypointid"
        case tripId = "tripid"
        case latitude
        case longitude
        case bufferRadius = "bufferradius"
        case sequenceOrder = "sequenceorder"
    }
}

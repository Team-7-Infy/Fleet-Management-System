import Foundation

struct Geofence: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var bufferRadius: Double
    var isActive: Bool
    var tripId: UUID

    enum CodingKeys: String, CodingKey {
        case id = "geofenceid"
        case bufferRadius = "bufferradius"
        case isActive = "isactive"
        case tripId = "tripid"
    }
}

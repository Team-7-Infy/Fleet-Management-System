import Foundation

struct DriverScorePenalty: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var driverId: UUID
    var points: Double
    var reason: String
    var appliedAt: Date
    var expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case driverId = "driver_id"
        case points
        case reason
        case appliedAt = "applied_at"
        case expiresAt = "expires_at"
    }
}

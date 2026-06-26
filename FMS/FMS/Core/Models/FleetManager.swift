import Foundation

struct FleetManager: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var userId: UUID

    enum CodingKeys: String, CodingKey {
        case id = "managerid"
        case userId = "userid"
    }
}

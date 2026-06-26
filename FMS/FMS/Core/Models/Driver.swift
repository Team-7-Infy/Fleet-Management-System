import Foundation

struct Driver: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var licenceNum: String
    var vehicleType: String
    var status: PersonnelStatus
    var userId: UUID

    enum CodingKeys: String, CodingKey {
        case id = "driverid"
        case licenceNum = "licencenum"
        case vehicleType = "vehicletype"
        case status
        case userId = "userid"
    }
}

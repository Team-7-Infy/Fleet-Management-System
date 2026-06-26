import Foundation

struct MaintenancePersonnel: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var status: PersonnelStatus
    var userId: UUID

    enum CodingKeys: String, CodingKey {
        case id = "personnelid"
        case status
        case userId = "userid"
    }
}

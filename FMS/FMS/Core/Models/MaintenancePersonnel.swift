import Foundation

struct MaintenancePersonnel: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var status: PersonnelStatus
    var userId: UUID
    var hourlyRate: Double

    enum CodingKeys: String, CodingKey {
        case id = "personnelid"
        case status
        case userId = "userid"
        case hourlyRate = "hourly_rate"
    }

    init(id: UUID, status: PersonnelStatus, userId: UUID, hourlyRate: Double) {
        self.id = id
        self.status = status
        self.userId = userId
        self.hourlyRate = hourlyRate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.status = try container.decode(PersonnelStatus.self, forKey: .status)
        self.userId = try container.decode(UUID.self, forKey: .userId)
        self.hourlyRate = try container.decodeIfPresent(Double.self, forKey: .hourlyRate) ?? 500.0
    }
}

import Foundation

struct MaintenanceTask: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var description: String
    var scheduledDate: DateOnly
    var isUrgent: Bool
    var scheduledBy: UUID?
    var executedBy: UUID?
    var status: MaintenanceTaskStatus

    enum CodingKeys: String, CodingKey {
        case id = "taskid"
        case description
        case scheduledDate = "scheduleddate"
        case isUrgent = "isurgent"
        case scheduledBy = "scheduledby"
        case executedBy = "executedby"
        case status
    }
}

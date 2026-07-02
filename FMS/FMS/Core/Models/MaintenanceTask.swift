import Foundation

struct MaintenanceTask: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String?
    var description: String
    var scheduledDate: DateOnly
    var isUrgent: Bool
    var scheduledBy: UUID?
    var executedBy: UUID?
    var status: MaintenanceTaskStatus
    var reportedDate: Date?
    var completedAt: Date?
    var timeTakenHours: Double?
    var partsSummary: String?
    var totalCost: Double?
    var photoUrls: [String]?

    enum CodingKeys: String, CodingKey {
        case id = "taskid"
        case title
        case description
        case scheduledDate = "scheduleddate"
        case isUrgent = "isurgent"
        case scheduledBy = "scheduledby"
        case executedBy = "executedby"
        case status
        case reportedDate = "reporteddate"
        case completedAt = "completedat"
        case timeTakenHours = "timetakenhours"
        case partsSummary = "partssummary"
        case totalCost = "totalcost"
        case photoUrls = "photourls"
    }
}

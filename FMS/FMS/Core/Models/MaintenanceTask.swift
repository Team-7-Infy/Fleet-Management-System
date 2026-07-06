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
    var labourCost: Double?
    var photoUrls: [String]?
    var elapsedTime: Int = 0

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
        case labourCost = "labour_cost"
        case photoUrls = "photourls"
        case elapsedTime = "elapsed_time"
    }
}

extension MaintenanceTask {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.description = try container.decode(String.self, forKey: .description)
        self.isUrgent = try container.decode(Bool.self, forKey: .isUrgent)
        self.scheduledBy = try container.decodeIfPresent(UUID.self, forKey: .scheduledBy)
        self.executedBy = try container.decodeIfPresent(UUID.self, forKey: .executedBy)
        self.status = try container.decode(MaintenanceTaskStatus.self, forKey: .status)
        self.photoUrls = try container.decodeIfPresent([String].self, forKey: .photoUrls)
        
        let anyContainer = try decoder.container(keyedBy: AnyCodingKey.self)
        
        // DateOnly scheduledDate
        if let sd = try? container.decode(DateOnly.self, forKey: .scheduledDate) {
            self.scheduledDate = sd
        } else if let sd = try? anyContainer.decode(DateOnly.self, forKey: AnyCodingKey(stringValue: "scheduleddate")) {
            self.scheduledDate = sd
        } else if let sd = try? anyContainer.decode(DateOnly.self, forKey: AnyCodingKey(stringValue: "scheduledDate")) {
            self.scheduledDate = sd
        } else {
            self.scheduledDate = DateOnly(wrappedValue: Date())
        }
        
        // Date? reportedDate
        self.reportedDate = (try? container.decodeIfPresent(Date.self, forKey: .reportedDate)) ??
                            (try? anyContainer.decodeIfPresent(Date.self, forKey: AnyCodingKey(stringValue: "reporteddate"))) ??
                            (try? anyContainer.decodeIfPresent(Date.self, forKey: AnyCodingKey(stringValue: "reportedDate")))
        
        // Date? completedAt
        self.completedAt = (try? container.decodeIfPresent(Date.self, forKey: .completedAt)) ??
                           (try? anyContainer.decodeIfPresent(Date.self, forKey: AnyCodingKey(stringValue: "completedat"))) ??
                           (try? anyContainer.decodeIfPresent(Date.self, forKey: AnyCodingKey(stringValue: "completedAt")))
        
        // Double? timeTakenHours
        self.timeTakenHours = (try? container.decodeIfPresent(Double.self, forKey: .timeTakenHours)) ??
                              (try? anyContainer.decodeIfPresent(Double.self, forKey: AnyCodingKey(stringValue: "timetakenhours"))) ??
                              (try? anyContainer.decodeIfPresent(Double.self, forKey: AnyCodingKey(stringValue: "timeTakenHours")))
        
        // String? partsSummary
        self.partsSummary = (try? container.decodeIfPresent(String.self, forKey: .partsSummary)) ??
                            (try? anyContainer.decodeIfPresent(String.self, forKey: AnyCodingKey(stringValue: "partssummary"))) ??
                            (try? anyContainer.decodeIfPresent(String.self, forKey: AnyCodingKey(stringValue: "partsSummary")))
        
        // Double? totalCost
        self.totalCost = (try? container.decodeIfPresent(Double.self, forKey: .totalCost)) ??
                         (try? anyContainer.decodeIfPresent(Double.self, forKey: AnyCodingKey(stringValue: "totalcost"))) ??
                         (try? anyContainer.decodeIfPresent(Double.self, forKey: AnyCodingKey(stringValue: "totalCost")))
        
        // Double? labourCost
        self.labourCost = (try? container.decodeIfPresent(Double.self, forKey: .labourCost)) ??
                          (try? anyContainer.decodeIfPresent(Double.self, forKey: AnyCodingKey(stringValue: "labour_cost"))) ??
                          (try? anyContainer.decodeIfPresent(Double.self, forKey: AnyCodingKey(stringValue: "labourCost")))
        
        // Int elapsedTime
        self.elapsedTime = (try? container.decode(Int.self, forKey: .elapsedTime)) ??
                           (try? anyContainer.decode(Int.self, forKey: AnyCodingKey(stringValue: "elapsed_time"))) ??
                           (try? anyContainer.decode(Int.self, forKey: AnyCodingKey(stringValue: "elapsedTime"))) ?? 0
    }
}

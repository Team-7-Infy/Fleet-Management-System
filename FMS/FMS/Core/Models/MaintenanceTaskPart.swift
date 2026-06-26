import Foundation

struct MaintenanceTaskPart: Codable, Hashable, Sendable {
    let taskId: UUID
    let partId: UUID
    var quantityUsed: Int

    enum CodingKeys: String, CodingKey {
        case taskId = "taskid"
        case partId = "partid"
        case quantityUsed = "quantityused"
    }
}

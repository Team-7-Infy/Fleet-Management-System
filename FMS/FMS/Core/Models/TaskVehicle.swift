import Foundation

struct TaskVehicle: Codable, Hashable, Sendable {
    let taskId: UUID
    let vin: UUID

    enum CodingKeys: String, CodingKey {
        case taskId = "taskid"
        case vin
    }
}

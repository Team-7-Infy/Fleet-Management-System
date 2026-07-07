import Foundation

struct DriverSchedule: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var driverId: UUID
    var startTime: Date
    var endTime: Date
    var isAvailable: Bool
    var notes: String?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case driverId = "driver_id"
        case startTime = "start_time"
        case endTime = "end_time"
        case isAvailable = "is_available"
        case notes
        case createdAt = "created_at"
    }
}

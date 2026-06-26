import Foundation

enum MaintenanceTaskStatus: String, Codable, CaseIterable {
    case scheduled = "scheduled"
    case assigned = "assigned"
    case inProgress = "in_progress"
    case completed = "completed"
}

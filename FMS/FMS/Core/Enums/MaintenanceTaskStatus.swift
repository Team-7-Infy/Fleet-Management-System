import Foundation

enum MaintenanceTaskStatus: String, Codable, CaseIterable {
    case scheduled = "scheduled"
    case assigned = "assigned"
    case inProgress = "in_progress"
    case onHold = "on_hold"
    case completed = "completed"
    case fake = "fake"

    var isOpen: Bool {
        switch self {
        case .scheduled, .assigned, .inProgress, .onHold: return true
        case .completed, .fake: return false
        }
    }
}

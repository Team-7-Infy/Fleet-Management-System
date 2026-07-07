import Foundation

enum MaintenanceTaskStatus: String, Codable, CaseIterable {
    case scheduled = "scheduled"
    case assigned = "assigned"
    case inProgress = "in_progress"
    case onHold = "on_hold"
    case completed = "completed"
    case verified = "verified"
    case closed = "closed"
    case fake = "fake"

    var isOpen: Bool {
        switch self {
        case .scheduled, .assigned, .inProgress, .onHold: return true
        case .completed, .verified, .closed, .fake: return false
        }
    }
}

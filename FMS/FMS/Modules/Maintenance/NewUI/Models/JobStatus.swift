import Foundation
import SwiftUI

enum JobStatus: String, CaseIterable, Codable, Hashable, Identifiable {
    case pending = "scheduled"
    case assigned = "assigned"
    case inProgress = "in_progress"
    case completed = "completed"
    case fake = "fake"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pending: "Pending"
        case .assigned: "Assigned"
        case .inProgress: "Under Maintenance"
        case .completed: "Completed"
        case .fake: "Flagged"
        }
    }

    var color: Color {
        switch self {
        case .pending: .secondary
        case .assigned: .blue
        case .inProgress: .orange
        case .completed: .green
        case .fake: .red
        }
    }
}

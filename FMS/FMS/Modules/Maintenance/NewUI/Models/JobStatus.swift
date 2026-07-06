import Foundation
import SwiftUI

enum JobStatus: String, CaseIterable, Codable, Hashable, Identifiable {
    case pending = "scheduled"
    case assigned = "assigned"
    case inProgress = "in_progress"
    case onHold = "on_hold"
    case completed = "completed"
    case fake = "fake"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pending: "Pending"
        case .assigned: "Assigned"
        case .inProgress: "Under Maintenance"
        case .onHold: "On Hold"
        case .completed: "Completed"
        case .fake: "Flagged"
        }
    }

    var color: Color {
        switch self {
        case .pending: AppColor.warning
        case .assigned: AppColor.inProgress
        case .inProgress: AppColor.inProgress
        case .onHold: .orange
        case .completed: AppColor.success
        case .fake: .red
        }
    }
}

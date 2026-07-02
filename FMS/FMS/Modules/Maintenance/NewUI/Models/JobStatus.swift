import Foundation
import SwiftUI

enum JobStatus: String, CaseIterable, Codable, Hashable, Identifiable {
    case pending = "scheduled"
    case assigned = "assigned"
    case inProgress = "in_progress"
    case completed = "completed"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pending: "Pending"
        case .assigned: "Assigned"
        case .inProgress: "Under Maintenance"
        case .completed: "Completed"
        }
    }

    var color: Color {
        switch self {
        case .pending: AppColor.warning
        case .assigned: AppColor.inProgress
        case .inProgress: AppColor.inProgress
        case .completed: AppColor.success
        }
    }
}

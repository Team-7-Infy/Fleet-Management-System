import Foundation

enum AppTab: String, CaseIterable, Identifiable {
    case dashboard
    case myJobs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .myJobs: "On Going"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: AppIcon.dashboard
        case .myJobs: AppIcon.jobs
        }
    }
}

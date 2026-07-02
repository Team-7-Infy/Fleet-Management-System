import Foundation

enum AppTab: String, CaseIterable, Identifiable {
    case dashboard
    case myJobs
    case inventory

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard:  "Dashboard"
        case .myJobs:     "On Going"
        case .inventory:  "Inventory"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard:  AppIcon.dashboard
        case .myJobs:     AppIcon.jobs
        case .inventory:  "shippingbox.fill"
        }
    }
}

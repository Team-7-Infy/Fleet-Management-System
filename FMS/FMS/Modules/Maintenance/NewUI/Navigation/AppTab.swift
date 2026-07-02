import Foundation

enum AppTab: String, CaseIterable, Identifiable {
    case dashboard
    case inventory

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .inventory: "Inventory"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: AppIcon.dashboard
        case .inventory: "shippingbox"
        }
    }
}

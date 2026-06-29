import Foundation
import SwiftUI

enum Priority: String, CaseIterable, Codable, Hashable, Identifiable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var title: String {
        switch self {
        case .low: "Low Priority"
        case .medium: "Medium Priority"
        case .high: "High Priority"
        }
    }

    var color: Color {
        switch self {
        case .low: .green
        case .medium: .orange
        case .high: .red
        }
    }
}

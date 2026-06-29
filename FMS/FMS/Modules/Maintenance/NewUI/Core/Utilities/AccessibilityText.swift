import Foundation

enum AccessibilityText {
    static func workOrder(_ identifier: String, status: String) -> String {
        "Work order \(identifier), status \(status)"
    }
}

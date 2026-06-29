import Foundation

extension String {
    var nonEmptyAccessibilityValue: String {
        isEmpty ? "Not available" : self
    }
}

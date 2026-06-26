import Foundation

extension Date {
    var iso8601String: String {
        ISO8601DateFormatter.iso8601Fractional.string(from: self)
    }
}

import Foundation

struct ValidationResult: Sendable {
    let isValid: Bool
    let message: String?

    static let valid = ValidationResult(isValid: true, message: nil)

    static func invalid(_ message: String) -> ValidationResult {
        ValidationResult(isValid: false, message: message)
    }
}

protocol Validator<T> {
    associatedtype T
    func validate(_ value: T) -> ValidationResult
}

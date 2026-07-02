import Foundation

struct User: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var email: String
    var aadhar: String
    var contact: Int64
    var role: UserRole
    var fName: String
    var lName: String
    var address: String
    var isActive: Bool
    var createdAt: Date
    var avatarUrl: String? = nil
    var firstTimeLogin: Bool = true

    enum CodingKeys: String, CodingKey {
        case id = "userid"
        case email
        case aadhar
        case contact
        case role
        case fName = "f_name"
        case lName = "l_name"
        case address
        case isActive = "isactive"
        case createdAt = "createdat"
        case avatarUrl = "avatarurl"
        case firstTimeLogin = "first_time_login"
    }

}

enum UserProfileValidationField: Hashable, Sendable {
    case name
    case email
    case aadhaar
    case contact
    case address
    case avatarURL
    case licenceNumber
}

struct UserProfileValidationIssue: Identifiable, Hashable, Sendable {
    var field: UserProfileValidationField
    var message: String

    var id: UserProfileValidationField { field }
}

enum UserProfileValidation {
    static func normalizedDigits(_ value: String) -> String {
        String(value.filter(\.isNumber))
    }

    static func normalizedName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizedEmail(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func normalizedAadhaar(_ value: String) -> String {
        normalizedDigits(value)
    }

    static func normalizedContact(_ value: String) -> String {
        normalizedDigits(value)
    }

    static func normalizedLicenceNumber(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }

    static func normalizedURL(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isValidName(_ value: String) -> Bool {
        let trimmed = normalizedName(value)
        guard (2...60).contains(trimmed.count) else { return false }
        return matches(trimmed, pattern: #"^[A-Za-z][A-Za-z .'-]*[A-Za-z]$"#)
    }

    static func isValidEmail(_ value: String) -> Bool {
        let email = normalizedEmail(value)
        guard email.count <= 254 else { return false }
        return matches(email, pattern: #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#)
    }

    static func isValidAadhaar(_ value: String) -> Bool {
        matches(normalizedAadhaar(value), pattern: #"^\d{12}$"#)
    }

    static func isValidContact(_ value: String) -> Bool {
        matches(normalizedContact(value), pattern: #"^[6-9]\d{9}$"#)
    }

    static func isValidAddress(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (5...160).contains(trimmed.count) else { return false }
        return matches(trimmed, pattern: #"^[A-Za-z0-9][A-Za-z0-9 .,'#/&()_-]*$"#)
    }

    static func isValidOptionalURL(_ value: String) -> Bool {
        let trimmed = normalizedURL(value)
        guard trimmed.isEmpty == false else { return true }
        return matches(trimmed, pattern: #"^https?:\/\/[A-Za-z0-9.-]+(?::\d{2,5})?(?:\/[^\s]*)?$"#)
    }

    static func isValidLicenceNumber(_ value: String, allowsPending: Bool = true) -> Bool {
        let licence = normalizedLicenceNumber(value)
        if allowsPending && licence == "PENDING" {
            return true
        }

        return matches(licence, pattern: #"^[A-Z]{2}[- ]?\d{2}[- ]?\d{4}[- ]?\d{4,7}$"#)
    }

    private static func matches(_ value: String, pattern: String) -> Bool {
        value.range(of: pattern, options: .regularExpression) != nil
    }
}

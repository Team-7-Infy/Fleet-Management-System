import Foundation

struct FleetManagerMetric: Identifiable {
    let id = UUID()
    var title: String
    var value: String
    var systemImage: String
}

struct FleetManagerUserForm {
    var name = ""
    var firstName = ""
    var lastName = ""
    var email = ""
    var aadhar = ""
    var contact = ""
    var address = ""
    var avatarUrl = ""
    var role: UserRole = .driver
    var licenceNumber = ""
    var vehicleType = "van"

    var normalizedEmail: String {
        UserProfileValidation.normalizedEmail(email)
    }

    var normalizedAadhaar: String {
        UserProfileValidation.normalizedAadhaar(aadhar)
    }

    var normalizedContact: String {
        UserProfileValidation.normalizedContact(contact)
    }

    var normalizedAddress: String {
        address.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedLicenceNumber: String {
        UserProfileValidation.normalizedLicenceNumber(licenceNumber)
    }

    var contactValue: Int64? {
        guard UserProfileValidation.isValidContact(contact) else { return nil }
        return Int64(normalizedContact)
    }

    var normalizedName: String {
        let directName = UserProfileValidation.normalizedName(name)
        if directName.isEmpty == false {
            return directName
        }

        return "\(firstName) \(lastName)"
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedNameParts: (first: String, last: String) {
        let parts = normalizedName
            .split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            .map(String.init)

        guard let first = parts.first else { return ("", "") }
        return (first, parts.count > 1 ? parts[1] : "")
    }

    var normalizedAvatarUrl: String? {
        let trimmed = UserProfileValidation.normalizedURL(avatarUrl)
        return trimmed.isEmpty ? nil : trimmed
    }

    var validationIssues: [UserProfileValidationIssue] {
        validationIssues()
    }

    var isValid: Bool {
        validationIssues.isEmpty
    }

    func validationIssues(
        requireAddress: Bool = false,
        requireDriverLicence: Bool = false
    ) -> [UserProfileValidationIssue] {
        var issues: [UserProfileValidationIssue] = []

        if UserProfileValidation.isValidName(normalizedName) == false {
            issues.append(UserProfileValidationIssue(
                field: .name,
                message: "Enter a valid name using letters, spaces, apostrophes, or hyphens."
            ))
        }

        if UserProfileValidation.isValidEmail(email) == false {
            issues.append(UserProfileValidationIssue(
                field: .email,
                message: "Enter a valid email address."
            ))
        }

        if UserProfileValidation.isValidAadhaar(aadhar) == false {
            issues.append(UserProfileValidationIssue(
                field: .aadhaar,
                message: "Aadhaar must be exactly 12 digits."
            ))
        }

        if UserProfileValidation.isValidContact(contact) == false {
            issues.append(UserProfileValidationIssue(
                field: .contact,
                message: "Contact must be a 10-digit mobile number starting with 6, 7, 8, or 9."
            ))
        }

        if requireAddress || normalizedAddress.isEmpty == false,
           UserProfileValidation.isValidAddress(address) == false {
            issues.append(UserProfileValidationIssue(
                field: .address,
                message: "Address must be 5-160 characters and use only common address characters."
            ))
        }

        if UserProfileValidation.isValidOptionalURL(avatarUrl) == false {
            issues.append(UserProfileValidationIssue(
                field: .avatarURL,
                message: "Photo URL must start with http:// or https://."
            ))
        }

        if role == .driver,
           requireDriverLicence || normalizedLicenceNumber.isEmpty == false,
           UserProfileValidation.isValidLicenceNumber(licenceNumber) == false {
            issues.append(UserProfileValidationIssue(
                field: .licenceNumber,
                message: "Licence must look like DL-042026-7101 or MH12 2026 1234567."
            ))
        }

        return issues
    }

    func validationMessage(for field: UserProfileValidationField) -> String? {
        validationIssues.first { $0.field == field }?.message
    }

    func makeUser(id: UUID = UUID()) throws -> User {
        if let issue = validationIssues.first {
            throw FleetManagerFormError.invalidUser(issue.message)
        }

        guard let contactValue else { throw FleetManagerFormError.invalidContact }
        let nameParts = normalizedNameParts

        return User(
            id: id,
            email: normalizedEmail,
            aadhar: normalizedAadhaar,
            contact: contactValue,
            role: role,
            fName: nameParts.first,
            lName: nameParts.last,
            address: normalizedAddress,
            isActive: true,
            createdAt: Date.now,
            avatarUrl: normalizedAvatarUrl
        )
    }
}

struct FleetManagerVehicleForm {
    var vin = ""
    var make = ""
    var model = ""
    var year = ""
    var licencePlate = ""
    var status: VehicleStatus = .active
    var vehicleType = "van"

    private static let indianStateCodes: Set<String> = [
        "AN", "AP", "AR", "AS", "BR", "CH", "CG", "DD", "DL", "DN", "GA", "GJ",
        "HP", "HR", "JH", "JK", "KA", "KL", "LA", "LD", "MH", "ML", "MN", "MP",
        "MZ", "NL", "OD", "OR", "PB", "PY", "RJ", "SK", "TN", "TR", "TS", "UK",
        "UP", "WB"
    ]

    private static let statePlatePattern = #"^[A-Z]{2}[0-9]{1,2}[A-Z]{1,3}[0-9]{1,4}$"#
    private static let bharatPlatePattern = #"^[0-9]{2}BH[0-9]{4}[A-Z]{1,2}$"#

    var vehicleId: UUID? {
        let trimmed = vin.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? UUID() : UUID(uuidString: trimmed)
    }

    var normalizedLicencePlate: String {
        Self.normalizedLicencePlate(licencePlate)
    }

    var yearValue: Int? {
        Int(year.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var licencePlateValidationMessage: String? {
        guard normalizedLicencePlate.isEmpty == false else { return nil }
        guard Self.isValidIndianLicencePlate(licencePlate) else {
            return "Use an Indian plate format like MH12AB1234, DL01AB1234, or 22BH1234AA."
        }
        return nil
    }

    var yearValidationMessage: String? {
        let trimmedYear = year.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedYear.isEmpty == false else { return nil }

        guard trimmedYear.count == 4, let yearValue else {
            return "Year must be 4 digits."
        }

        let maximumYear = Calendar.current.component(.year, from: Date()) + 1
        guard (1980...maximumYear).contains(yearValue) else {
            return "Year must be between 1980 and \(maximumYear)."
        }

        return nil
    }

    var validationMessage: String? {
        if normalizedLicencePlate.isEmpty {
            return "Enter an Indian vehicle plate number."
        }

        if let licencePlateValidationMessage {
            return licencePlateValidationMessage
        }

        if make.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Enter the vehicle make."
        }

        if model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Enter the vehicle model."
        }

        if year.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Enter the vehicle year."
        }

        if let yearValidationMessage {
            return yearValidationMessage
        }

        if vehicleId == nil {
            return "VIN must be empty for auto-generation or a valid UUID."
        }

        return nil
    }

    var isValid: Bool {
        vehicleId != nil &&
        make.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false &&
        model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false &&
        Self.isValidIndianLicencePlate(licencePlate) &&
        yearValue != nil &&
        yearValidationMessage == nil
    }

    func makeVehicle() throws -> Vehicle {
        guard let vehicleId else { throw FleetManagerFormError.invalidVehicleIdentifier }
        guard isValid, let yearValue else {
            throw FleetManagerFormError.invalidVehicle(validationMessage ?? "Complete vehicle details.")
        }

        return Vehicle(
            id: vehicleId,
            make: make.trimmingCharacters(in: .whitespacesAndNewlines),
            model: model.trimmingCharacters(in: .whitespacesAndNewlines),
            year: yearValue,
            licencePlate: normalizedLicencePlate,
            status: status,
            vehicleType: vehicleType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            driverId: nil
        )
    }

    static func sanitizedLicencePlateInput(_ value: String) -> String {
        String(
            value
                .uppercased()
                .filter { $0.isLetter || $0.isNumber || $0.isWhitespace || $0 == "-" }
                .prefix(16)
        )
    }

    static func normalizedLicencePlate(_ value: String) -> String {
        value
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    static func isValidIndianLicencePlate(_ value: String) -> Bool {
        let normalized = normalizedLicencePlate(value)

        if normalized.range(of: bharatPlatePattern, options: .regularExpression) != nil {
            return true
        }

        guard normalized.range(of: statePlatePattern, options: .regularExpression) != nil else {
            return false
        }

        return indianStateCodes.contains(String(normalized.prefix(2)))
    }
}

struct FleetManagerTripForm {
    var startLocation = ""
    var endLocation = ""
    var startTime = Date()
    var endTime: Date?
    var vehicleId: UUID?
    var driverId: UUID?
    var status: TripStatus = .pending

    var isValid: Bool {
        startLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false &&
        endLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false &&
        vehicleId != nil &&
        driverId != nil
    }

    func makeTrip() throws -> Trip {
        guard let vehicleId, let driverId else { throw FleetManagerFormError.missingSelection }

        return Trip(
            id: UUID(),
            startLocation: startLocation.trimmingCharacters(in: .whitespacesAndNewlines),
            endLocation: endLocation.trimmingCharacters(in: .whitespacesAndNewlines),
            startTime: startTime,
            endTime: endTime,
            vehicleId: vehicleId,
            driverId: driverId,
            status: status
        )
    }
}

struct FleetManagerMaintenanceTaskForm {
    var title = ""
    var description = ""
    var scheduledDate = Date()
    var isUrgent = false
    var vehicleId: UUID?
    var scheduledBy: UUID?
    var executedBy: UUID?
    var status: MaintenanceTaskStatus = .scheduled
    var photoUrl = ""

    var isValid: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false &&
        description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    func makeTask() -> MaintenanceTask {
        let photo = photoUrl.trimmingCharacters(in: .whitespacesAndNewlines)

        return MaintenanceTask(
            id: UUID(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            scheduledDate: DateOnly(wrappedValue: scheduledDate),
            isUrgent: isUrgent,
            scheduledBy: scheduledBy,
            executedBy: executedBy,
            status: status,
            reportedDate: Date(),
            photoUrls: photo.isEmpty ? nil : [photo]
        )
    }
}

enum FleetManagerFormError: LocalizedError {
    case invalidUser(String)
    case invalidContact
    case invalidVehicleIdentifier
    case invalidVehicle(String)
    case missingSelection

    var errorDescription: String? {
        switch self {
        case let .invalidUser(message):
            return message
        case .invalidContact:
            return "Enter a valid contact number."
        case .invalidVehicleIdentifier:
            return "VIN must be empty for auto-generation or a valid UUID."
        case let .invalidVehicle(message):
            return message
        case .missingSelection:
            return "Select the required driver and vehicle."
        }
    }
}

extension User {
    var displayName: String {
        let name = "\(fName) \(lName)".trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? email : name
    }

    var shortUID: String {
        String(id.uuidString.prefix(8)).uppercased()
    }

    var avatarImageURL: URL? {
        if let avatarUrl,
           let url = URL(string: avatarUrl) {
            return url
        }

        let seed = "\(displayName)-\(email)-\(role.rawValue)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? id.uuidString
        return URL(string: "https://i.pravatar.cc/240?u=\(seed)")
    }
}

extension MaintenanceTask {
    var displayTitle: String {
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmedTitle.isEmpty == false {
            return trimmedTitle
        }

        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedDescription.count > 52 else { return trimmedDescription }
        return "\(trimmedDescription.prefix(49))..."
    }

    var reportedOrScheduledDate: Date {
        reportedDate ?? scheduledDate.date
    }

    var hoursAgoText: String {
        let hours = max(0, Calendar.current.dateComponents([.hour], from: reportedOrScheduledDate, to: Date()).hour ?? 0)
        if hours < 1 {
            return "Just now"
        }
        return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
    }

    var formattedCost: String {
        guard let totalCost else { return "Not recorded" }
        return totalCost.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }
}

extension UserRole: Identifiable {
    var id: String { rawValue }

    var title: String {
        switch self {
        case .fleetManager:
            return "Fleet Manager"
        case .driver:
            return "Driver"
        case .maintenancePersonnel:
            return "Maintenance"
        }
    }
}

extension VehicleStatus: Identifiable {
    var id: String { rawValue }

    var title: String {
        switch self {
        case .active:
            return "Active"
        case .inactive:
            return "Inactive"
        case .maintenance:
            return "Maintenance"
        }
    }
}

extension TripStatus: Identifiable {
    var id: String { rawValue }

    var title: String {
        switch self {
        case .pending:
            return "Pending"
        case .accepted:
            return "Accepted"
        case .rejectionPending:
            return "Rejection Pending"
        case .rejected:
            return "Rejected"
        case .inProgress:
            return "In Progress"
        case .completed:
            return "Completed"
        }
    }
}

extension MaintenanceTaskStatus: Identifiable {
    var id: String { rawValue }

    var title: String {
        switch self {
        case .scheduled:
            return "Scheduled"
        case .assigned:
            return "Assigned"
        case .inProgress:
            return "In Progress"
        case .completed:
            return "Completed"
        }
    }
}

extension PersonnelStatus: Identifiable {
    var id: String { rawValue }

    var title: String {
        switch self {
        case .active:
            return "Active"
        case .inactive:
            return "Inactive"
        }
    }
}

extension DateOnly {
    var date: Date {
        wrappedValue
    }
}

enum FleetManagerFormat {
    static let day: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static let shortDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

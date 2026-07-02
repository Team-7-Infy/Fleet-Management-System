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

    var contactValue: Int64? {
        Int64(contact.filter(\.isNumber))
    }

    var normalizedName: String {
        let directName = name.trimmingCharacters(in: .whitespacesAndNewlines)
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
        let trimmed = avatarUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var isValid: Bool {
        guard email.contains("@"),
              normalizedName.isEmpty == false,
              contactValue != nil
        else {
            return false
        }

        return true
    }

    func makeUser(id: UUID = UUID()) throws -> User {
        guard let contactValue else { throw FleetManagerFormError.invalidContact }
        let nameParts = normalizedNameParts

        return User(
            id: id,
            email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            aadhar: aadhar.trimmingCharacters(in: .whitespacesAndNewlines),
            contact: contactValue,
            role: role,
            fName: nameParts.first,
            lName: nameParts.last,
            address: address.trimmingCharacters(in: .whitespacesAndNewlines),
            isActive: true,
            createdAt: Date(),
            avatarUrl: normalizedAvatarUrl
        )
    }
}

struct FleetManagerVehicleForm {
    var vin = ""
    var make = ""
    var model = ""
    var year = Calendar.current.component(.year, from: Date())
    var licencePlate = ""
    var status: VehicleStatus = .active
    var vehicleType = "van"

    var vehicleId: UUID? {
        let trimmed = vin.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? UUID() : UUID(uuidString: trimmed)
    }

    var isValid: Bool {
        vehicleId != nil &&
        make.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false &&
        model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false &&
        licencePlate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false &&
        year >= 1980
    }

    func makeVehicle() throws -> Vehicle {
        guard let vehicleId else { throw FleetManagerFormError.invalidVehicleIdentifier }

        return Vehicle(
            id: vehicleId,
            make: make.trimmingCharacters(in: .whitespacesAndNewlines),
            model: model.trimmingCharacters(in: .whitespacesAndNewlines),
            year: year,
            licencePlate: licencePlate.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            status: status,
            vehicleType: vehicleType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            driverId: nil
        )
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
    case invalidContact
    case invalidVehicleIdentifier
    case missingSelection

    var errorDescription: String? {
        switch self {
        case .invalidContact:
            return "Enter a valid contact number."
        case .invalidVehicleIdentifier:
            return "VIN must be empty for auto-generation or a valid UUID."
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

import Foundation

struct FleetManagerMetric: Identifiable {
    let id = UUID()
    var title: String
    var value: String
    var systemImage: String
}

struct FleetManagerUserForm {
    var firstName = ""
    var lastName = ""
    var email = ""
    var aadhar = ""
    var contact = ""
    var address = ""
    var role: UserRole = .driver
    var licenceNumber = ""
    var vehicleType = "van"

    var contactValue: Int64? {
        Int64(contact.filter(\.isNumber))
    }

    var isValid: Bool {
        guard email.contains("@"),
              firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
              lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
              aadhar.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
              address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
              contactValue != nil
        else {
            return false
        }

        if role == .driver {
            return licenceNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        }

        return true
    }

    func makeUser() throws -> User {
        guard let contactValue else { throw FleetManagerFormError.invalidContact }

        return User(
            id: UUID(),
            email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            aadhar: aadhar.trimmingCharacters(in: .whitespacesAndNewlines),
            contact: contactValue,
            role: role,
            fName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
            lName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
            address: address.trimmingCharacters(in: .whitespacesAndNewlines),
            isActive: true,
            createdAt: Date()
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
    var description = ""
    var scheduledDate = Date()
    var isUrgent = false
    var vehicleId: UUID?
    var scheduledBy: UUID?
    var executedBy: UUID?
    var status: MaintenanceTaskStatus = .scheduled

    var isValid: Bool {
        description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    func makeTask() -> MaintenanceTask {
        MaintenanceTask(
            id: UUID(),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            scheduledDate: DateOnly(wrappedValue: scheduledDate),
            isUrgent: isUrgent,
            scheduledBy: scheduledBy,
            executedBy: executedBy,
            status: status
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
        "\(fName) \(lName)".trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var avatarImageURL: URL? {
        if let avatarUrl,
           let url = URL(string: avatarUrl) {
            return url
        }

        let seed = "\(displayName)-\(email)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? id.uuidString
        return URL(string: "https://api.dicebear.com/9.x/initials/png?seed=\(seed)&backgroundColor=167d7f,4f46e5,b7791f,2e7d32&fontFamily=Helvetica")
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
        case .rejected:
            return "Rejected"
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

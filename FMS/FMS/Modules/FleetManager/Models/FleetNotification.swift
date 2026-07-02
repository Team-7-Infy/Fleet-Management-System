import SwiftUI

enum FleetNotificationCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case trips
    case maintenance
    case vehicles
    case users
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .trips:
            return "Trips"
        case .maintenance:
            return "Maintenance"
        case .vehicles:
            return "Vehicles"
        case .users:
            return "Users"
        case .system:
            return "System"
        }
    }

    var systemImage: String {
        switch self {
        case .trips:
            return "point.topleft.down.curvedto.point.bottomright.up"
        case .maintenance:
            return "wrench.and.screwdriver.fill"
        case .vehicles:
            return "car.2.fill"
        case .users:
            return "person.2.fill"
        case .system:
            return "bell.fill"
        }
    }

    var tint: Color {
        switch self {
        case .trips:
            return FleetPalette.accent
        case .maintenance:
            return FleetPalette.warning
        case .vehicles:
            return FleetPalette.success
        case .users:
            return FleetPalette.accent
        case .system:
            return FleetPalette.neutral
        }
    }
}

enum FleetNotificationFilter: String, CaseIterable, Identifiable {
    case all
    case trips
    case maintenance
    case vehicles
    case users
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .trips:
            return FleetNotificationCategory.trips.title
        case .maintenance:
            return FleetNotificationCategory.maintenance.title
        case .vehicles:
            return FleetNotificationCategory.vehicles.title
        case .users:
            return FleetNotificationCategory.users.title
        case .system:
            return FleetNotificationCategory.system.title
        }
    }

    var category: FleetNotificationCategory? {
        switch self {
        case .all:
            return nil
        case .trips:
            return .trips
        case .maintenance:
            return .maintenance
        case .vehicles:
            return .vehicles
        case .users:
            return .users
        case .system:
            return .system
        }
    }

    var systemImage: String {
        category?.systemImage ?? "tray.full.fill"
    }

    var tint: Color {
        category?.tint ?? FleetPalette.accent
    }
}

struct FleetNotification: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var recipientUserId: UUID
    var actorUserId: UUID?
    var category: FleetNotificationCategory
    var title: String
    var message: String
    var relatedTable: String?
    var relatedId: UUID?
    var isRead: Bool
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id = "notificationid"
        case recipientUserId = "recipient_userid"
        case actorUserId = "actor_userid"
        case category
        case title
        case message
        case relatedTable = "related_table"
        case relatedId = "related_id"
        case isRead = "is_read"
        case createdAt = "createdat"
    }
}

extension FleetNotification {
    static func sampleNotifications(recipientId: UUID) -> [FleetNotification] {
        let now = Date()

        return [
            FleetNotification(
                id: UUID(uuidString: "A67B4B10-8E3F-44A1-9BA3-4C70A9F6A001")!,
                recipientUserId: recipientId,
                actorUserId: nil,
                category: .trips,
                title: "Trip awaiting dispatch",
                message: "Airport pickup is scheduled and waiting for driver acceptance.",
                relatedTable: "trips",
                relatedId: nil,
                isRead: false,
                createdAt: now.addingTimeInterval(-12 * 60)
            ),
            FleetNotification(
                id: UUID(uuidString: "A67B4B10-8E3F-44A1-9BA3-4C70A9F6A002")!,
                recipientUserId: recipientId,
                actorUserId: nil,
                category: .maintenance,
                title: "Minor service delay",
                message: "Brake inspection is running behind schedule by 20 minutes.",
                relatedTable: "maintenance_tasks",
                relatedId: nil,
                isRead: false,
                createdAt: now.addingTimeInterval(-38 * 60)
            ),
            FleetNotification(
                id: UUID(uuidString: "A67B4B10-8E3F-44A1-9BA3-4C70A9F6A003")!,
                recipientUserId: recipientId,
                actorUserId: nil,
                category: .vehicles,
                title: "Vehicle check completed",
                message: "MH 12 AB 4587 passed inspection and is ready for assignment.",
                relatedTable: "vehicles",
                relatedId: nil,
                isRead: true,
                createdAt: now.addingTimeInterval(-74 * 60)
            ),
            FleetNotification(
                id: UUID(uuidString: "A67B4B10-8E3F-44A1-9BA3-4C70A9F6A004")!,
                recipientUserId: recipientId,
                actorUserId: nil,
                category: .users,
                title: "New driver profile added",
                message: "Isha Bansal is active and available for van assignments.",
                relatedTable: "users",
                relatedId: nil,
                isRead: false,
                createdAt: now.addingTimeInterval(-2 * 60 * 60)
            ),
            FleetNotification(
                id: UUID(uuidString: "A67B4B10-8E3F-44A1-9BA3-4C70A9F6A005")!,
                recipientUserId: recipientId,
                actorUserId: nil,
                category: .system,
                title: "Daily summary ready",
                message: "Fleet health and trip completion reports are ready to review.",
                relatedTable: nil,
                relatedId: nil,
                isRead: true,
                createdAt: now.addingTimeInterval(-3 * 60 * 60)
            )
        ]
    }
}

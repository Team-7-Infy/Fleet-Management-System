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
            return Color.purple
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

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

    init(databaseValue: String) {
        let normalizedValue = databaseValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if normalizedValue.contains("trip") {
            self = .trips
        } else if normalizedValue.contains("maintenance")
            || normalizedValue.contains("service")
            || normalizedValue.contains("work_order") {
            self = .maintenance
        } else if normalizedValue.contains("vehicle") {
            self = .vehicles
        } else if normalizedValue.contains("user") || normalizedValue.contains("driver") {
            self = .users
        } else {
            self = .system
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
    var recipientUserId: UUID?
    var actorUserId: UUID? = nil
    var category: FleetNotificationCategory
    var title: String
    var message: String
    var relatedTable: String? = nil
    var relatedId: UUID?
    var isRead: Bool
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case recipientUserId = "recipient_id"
        case category = "type"
        case title
        case message
        case relatedId = "reference_id"
        case isRead = "is_read"
        case createdAt = "created_at"
    }

    init(
        id: UUID,
        recipientUserId: UUID?,
        actorUserId: UUID? = nil,
        category: FleetNotificationCategory,
        title: String,
        message: String,
        relatedTable: String? = nil,
        relatedId: UUID?,
        isRead: Bool,
        createdAt: Date
    ) {
        self.id = id
        self.recipientUserId = recipientUserId
        self.actorUserId = actorUserId
        self.category = category
        self.title = title
        self.message = message
        self.relatedTable = relatedTable
        self.relatedId = relatedId
        self.isRead = isRead
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        recipientUserId = try container.decodeIfPresent(UUID.self, forKey: .recipientUserId)
        let type = try container.decode(String.self, forKey: .category)
        category = FleetNotificationCategory(databaseValue: type)
        title = try container.decode(String.self, forKey: .title)
        message = try container.decode(String.self, forKey: .message)
        relatedId = try container.decodeIfPresent(UUID.self, forKey: .relatedId)
        isRead = try container.decodeIfPresent(Bool.self, forKey: .isRead) ?? false
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(recipientUserId, forKey: .recipientUserId)
        try container.encode(category.rawValue, forKey: .category)
        try container.encode(title, forKey: .title)
        try container.encode(message, forKey: .message)
        try container.encodeIfPresent(relatedId, forKey: .relatedId)
        try container.encode(isRead, forKey: .isRead)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

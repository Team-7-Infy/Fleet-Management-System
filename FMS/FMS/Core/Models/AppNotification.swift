import Foundation

struct AppNotification: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let message: String
    let type: String
    var isRead: Bool
    let referenceId: UUID?
    let recipientId: UUID?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case message
        case type
        case isRead = "is_read"
        case referenceId = "reference_id"
        case recipientId = "recipient_id"
        case createdAt = "created_at"
    }
    
    var sfSymbolName: String {
        switch type {
        case "inventory_alert":
            return "shippingbox.fill"
        case "trip_assignment":
            return "car.fill"
        case "route_deviation":
            return "exclamationmark.triangle.fill"
        case "maintenance_due":
            return "wrench.and.screwdriver.fill"
        case "work_order_assigned", "work_order_assigned_urgent":
            let lowerTitle = title.lowercased()
            if lowerTitle.contains("oil") || lowerTitle.contains("flush") {
                return "drop.fill"
            } else if lowerTitle.contains("brake") {
                return "circle.circle.fill"
            } else if lowerTitle.contains("tire") || lowerTitle.contains("wheel") {
                return "circle.grid.cross.fill"
            } else if lowerTitle.contains("battery") || lowerTitle.contains("spark") {
                return "bolt.fill"
            } else if lowerTitle.contains("engine") || lowerTitle.contains("diagnostics") {
                return "engine.combustion.fill"
            } else if lowerTitle.contains("wiper") {
                return "cloud.rain.fill"
            } else if lowerTitle.contains("filter") {
                return "wind"
            }
            return "wrench.fill"
        default:
            return "bell.fill"
        }
    }
}

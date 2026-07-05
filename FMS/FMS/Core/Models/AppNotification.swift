import Foundation

struct AppNotification: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var message: String
    var type: String
    var referenceId: UUID?
    var recipientId: UUID?
    var isRead: Bool
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case message
        case type
        case referenceId = "reference_id"
        case recipientId = "recipient_id"
        case isRead = "is_read"
        case createdAt = "created_at"
    }
}

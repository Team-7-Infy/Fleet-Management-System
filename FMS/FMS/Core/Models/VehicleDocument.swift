import Foundation

struct VehicleDocument: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var vehicleId: UUID
    var docType: String
    var docNumber: String
    var issueDate: DateOnly
    var expiryDate: DateOnly
    var fileUrl: String?
    var deletedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case vehicleId = "vehicle_id"
        case docType = "doc_type"
        case docNumber = "doc_number"
        case issueDate = "issue_date"
        case expiryDate = "expiry_date"
        case fileUrl = "file_url"
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

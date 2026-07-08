import Foundation

struct SOSEvent: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let tripId: UUID?
    let driverId: UUID
    let vehicleId: String?
    let type: String
    var status: SOSStatus
    let latitude: Double
    let longitude: Double
    var resolvedBy: UUID?
    var resolvedAt: Date?
    var notes: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case tripId = "trip_id"
        case driverId = "driver_id"
        case vehicleId = "vehicle_id"
        case type
        case status
        case latitude
        case longitude
        case resolvedBy = "resolved_by"
        case resolvedAt = "resolved_at"
        case notes
        case createdAt = "created_at"
    }

    enum SOSStatus: String, Codable, CaseIterable, Sendable {
        case pending = "pending"
        case acknowledged = "acknowledged"
        case resolved = "resolved"
    }
}

import Foundation

struct VehicleInspection: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var tripId: UUID
    var vehicleId: UUID
    var driverId: UUID
    var type: String
    var status: String
    var odometerReading: Double?
    var fuelLevel: Double?
    var notes: String?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case tripId = "trip_id"
        case vehicleId = "vehicle_id"
        case driverId = "driver_id"
        case type
        case status
        case odometerReading = "odometer_reading"
        case fuelLevel = "fuel_level"
        case notes
        case createdAt = "created_at"
    }
}

struct InspectionItemDB: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var inspectionId: UUID
    var itemName: String
    var status: String
    var failDescription: String?
    var failPhotoUrl: String?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case inspectionId = "inspection_id"
        case itemName = "item_name"
        case status
        case failDescription = "fail_description"
        case failPhotoUrl = "fail_photo_url"
        case createdAt = "created_at"
    }
}

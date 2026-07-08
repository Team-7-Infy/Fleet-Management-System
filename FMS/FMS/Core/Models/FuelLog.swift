import Foundation

struct FuelLog: Identifiable, Codable, Sendable {
    let id: UUID
    let date: Date
    let vehicleId: UUID
    let tripId: UUID?
    let fuelType: String
    let cost: Double?
    let volumeFilled: Double?
    let pricePerLiter: Double?
    let currentFuelLevel: Double?
    let receiptCode: String?
    let receiptImageUrl: String?
    let kWhAdded: Double?
    let chargePercentBefore: Double?
    let chargePercentAfter: Double?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case vehicleId = "vehicle_id"
        case tripId = "trip_id"
        case fuelType = "fuel_type"
        case cost
        case volumeFilled = "volume_filled"
        case pricePerLiter = "price_per_liter"
        case currentFuelLevel = "current_fuel_level"
        case receiptCode = "receipt_code"
        case receiptImageUrl = "receipt_image_url"
        case kWhAdded = "kwh_added"
        case chargePercentBefore = "charge_percent_before"
        case chargePercentAfter = "charge_percent_after"
        case createdAt = "created_at"
    }
}

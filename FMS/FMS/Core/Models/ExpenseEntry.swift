import Foundation

struct ExpenseEntry: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var tripId: UUID?
    var vehicleId: UUID
    var driverId: UUID
    var expenseType: String
    var liters: Double?
    var costPerLiter: Double?
    var fuelType: String?
    var totalCost: Double
    var odometerReading: Double?
    var receiptImageUrl: String?
    var receiptOcrData: String?
    var locationLat: Double?
    var locationLng: Double?
    var notes: String?
    var createdAt: Date

    var quantityUnit: String {
        fuelType == "cng" ? "kg" : "L"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case tripId = "trip_id"
        case vehicleId = "vehicle_id"
        case driverId = "driver_id"
        case expenseType = "expense_type"
        case liters
        case costPerLiter = "cost_per_liter"
        case fuelType = "fuel_type"
        case totalCost = "total_cost"
        case odometerReading = "odometer_reading"
        case receiptImageUrl = "receipt_image_url"
        case receiptOcrData = "receipt_ocr_data"
        case locationLat = "location_lat"
        case locationLng = "location_lng"
        case notes
        case createdAt = "created_at"
    }
}

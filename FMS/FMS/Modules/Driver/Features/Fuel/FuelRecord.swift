import Foundation

struct FuelRecord: Identifiable, Codable {
    let id: UUID
    let date: Date
    var vehicleId: String
    var tripId: String?
    var fuelType: FuelType
    var amountRequested: Double?
    var cost: Double?
    var volumeFilled: Double?
    var pricePerLiter: Double?
    var currentFuelLevel: Double
    var receiptCode: String?
    var receiptImageURL: String?

    // EV-specific fields
    var kWhAdded: Double?
    var chargePercentBefore: Double?
    var chargePercentAfter: Double?

    init(id: UUID = UUID(), date: Date, vehicleId: String, tripId: String? = nil, fuelType: FuelType, amountRequested: Double? = nil, cost: Double? = nil, volumeFilled: Double? = nil, pricePerLiter: Double? = nil, currentFuelLevel: Double, receiptCode: String? = nil, receiptImageURL: String? = nil, kWhAdded: Double? = nil, chargePercentBefore: Double? = nil, chargePercentAfter: Double? = nil) {
        self.id = id
        self.date = date
        self.vehicleId = vehicleId
        self.tripId = tripId
        self.fuelType = fuelType
        self.amountRequested = amountRequested
        self.cost = cost
        self.volumeFilled = volumeFilled
        self.pricePerLiter = pricePerLiter
        self.currentFuelLevel = currentFuelLevel
        self.receiptCode = receiptCode
        self.receiptImageURL = receiptImageURL
        self.kWhAdded = kWhAdded
        self.chargePercentBefore = chargePercentBefore
        self.chargePercentAfter = chargePercentAfter
    }

    enum FuelType: String, Codable, CaseIterable {
        case diesel = "Diesel"
        case petrol = "Petrol"
        case cng = "CNG"
        case electric = "Electric (EV)"
    }

    var refillUnit: String {
        fuelType == .cng ? "kg" : fuelType == .electric ? "kWh" : "L"
    }

    var priceUnit: String {
        fuelType == .cng ? "kg" : fuelType == .electric ? "kWh" : "L"
    }
}

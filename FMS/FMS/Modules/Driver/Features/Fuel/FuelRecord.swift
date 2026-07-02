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
    var status: RequestStatus
    var receiptCode: String?
    var receiptImageURL: String?

    init(id: UUID = UUID(), date: Date, vehicleId: String, tripId: String? = nil, fuelType: FuelType, amountRequested: Double? = nil, cost: Double? = nil, volumeFilled: Double? = nil, pricePerLiter: Double? = nil, currentFuelLevel: Double, status: RequestStatus, receiptCode: String? = nil, receiptImageURL: String? = nil) {
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
        self.status = status
        self.receiptCode = receiptCode
        self.receiptImageURL = receiptImageURL
    }

    enum FuelType: String, Codable, CaseIterable {
        case diesel = "Diesel"
        case petrol = "Petrol"
        case ev = "Electric Charge"
    }

    enum RequestStatus: String, Codable {
        case pending = "Pending Approval"
        case approved = "Approved"
        case rejected = "Rejected"
        case completed = "Completed"
    }

    var refillUnit: String {
        fuelType == .ev ? "kW" : "L"
    }

    var priceUnit: String {
        fuelType == .ev ? "kW" : "L"
    }
}

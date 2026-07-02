import Foundation

struct Trip: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var startLocation: String
    var endLocation: String
    var startTime: Date
    var endTime: Date?
    var vehicleId: UUID
    var driverId: UUID?
    var status: TripStatus
    var rejectionReason: String?
    var finalOdometer: Double?
    var finalFuelLevel: Double?
    var driverNote: String?

    enum CodingKeys: String, CodingKey {
        case id = "tripid"
        case startLocation = "startlocation"
        case endLocation = "endlocation"
        case startTime = "starttime"
        case endTime = "endtime"
        case vehicleId = "vehicleid"
        case driverId = "driverid"
        case status
        case rejectionReason = "rejection_reason"
        case finalOdometer = "final_odometer"
        case finalFuelLevel = "final_fuel_level"
        case driverNote = "driver_note"
    }
}

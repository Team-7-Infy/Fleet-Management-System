import Foundation

struct Trip: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var startLocation: String
    var endLocation: String
    var startTime: Date
    var endTime: Date?
    var actualStartTime: Date?
    var vehicleId: UUID?
    var driverId: UUID?
    var status: TripStatus
    var rejectionReason: String?
    var distanceKm: Double?
    var fuelCost: Double?
    var miscellaneousCost: Double?
    var finalOdometer: Double?
    var finalFuelLevel: Double?
    var driverNote: String?
    var vehicleTypeRequested: String?
    var postTripInspectionDueAt: Date?
    var cancellationReason: String?
    var postTripFlagged: Bool = false
    var fuelConsumed: Double?
    var fuelConsumedFlagged: Bool = false

    enum CodingKeys: String, CodingKey {
        case id = "tripid"
        case startLocation = "startlocation"
        case endLocation = "endlocation"
        case startTime = "starttime"
        case endTime = "endtime"
        case actualStartTime = "actual_start_time"
        case vehicleId = "vehicleid"
        case driverId = "driverid"
        case status
        case rejectionReason = "rejection_reason"
        case distanceKm = "distance_km"
        case fuelCost = "fuel_cost"
        case miscellaneousCost = "miscellaneous_cost"
        case finalOdometer = "final_odometer"
        case finalFuelLevel = "final_fuel_level"
        case driverNote = "driver_note"
        case vehicleTypeRequested = "vehicletype_requested"
        case postTripInspectionDueAt = "post_trip_inspection_due_at"
        case cancellationReason = "cancellation_reason"
        case postTripFlagged = "post_trip_flagged"
        case fuelConsumed = "fuel_consumed"
        case fuelConsumedFlagged = "fuel_consumed_flagged"
    }
}

extension Trip {
    var displayId: String { id.displayId(.trip) }

    var totalCost: Double {
        (fuelCost ?? 0) + (miscellaneousCost ?? 0)
    }

    var effectiveTripStatus: TripStatus {
        if actualStartTime != nil && endTime != nil {
            return .completed
        }
        return status
    }

    var effectiveStartTime: Date {
        actualStartTime ?? startTime
    }
}

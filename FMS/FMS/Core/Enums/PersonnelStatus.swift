import Foundation

enum PersonnelStatus: String, Codable, CaseIterable {
    case active = "active"
    case inactive = "inactive"
    case available = "available"
    case onTrip = "on_trip"
    case scheduled = "scheduled"
    case unavailable = "unavailable"
    case inService = "in_service"
}

import Foundation

struct Incident: Identifiable, Codable {
    let id: UUID
    let date: Date
    var type: IncidentType
    var description: String
    var latitude: Double?
    var longitude: Double?
    var photoURLs: [String]
    var status: IncidentStatus
    var tripId: String?

    init(id: UUID = UUID(), date: Date, type: IncidentType, description: String, latitude: Double? = nil, longitude: Double? = nil, photoURLs: [String], status: IncidentStatus, tripId: String? = nil) {
        self.id = id
        self.date = date
        self.type = type
        self.description = description
        self.latitude = latitude
        self.longitude = longitude
        self.photoURLs = photoURLs
        self.status = status
        self.tripId = tripId
    }

    enum IncidentType: String, Codable, CaseIterable {
        case accident = "Accident"
        case vehicleDamage = "Vehicle Damage"
        case trafficViolation = "Traffic Violation"
        case theft = "Theft/Vandalism"
        case other = "Other"
    }

    enum IncidentStatus: String, Codable {
        case submitted = "Submitted"
        case underReview = "Under Review"
        case resolved = "Resolved"
    }
}

import Foundation

struct DriverScore: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var driverId: UUID
    var overallScore: Double
    /// Inspection compliance SCORE (0-100, higher=better). Despite the name, this is NOT a false rate — it stores a pass-rate score.
    var inspectionFalseRate: Double?
    /// Route adherence SCORE (0-100, higher=better). Despite the name, this is NOT a violation rate — it stores a safety/route-adherence score.
    var geofenceViolationRate: Double?
    /// Schedule compliance SCORE (0-100, higher=better). Despite the name, this is NOT a violation rate — it stores an on-time completion score.
    var complianceViolationRate: Double?
    var mileageAccuracy: Double?
    var calculatedAt: Date
    var geofenceEventCount: Int?
    var speedingEventCount: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case driverId = "driver_id"
        case overallScore = "overall_score"
        case inspectionFalseRate = "inspection_false_rate"
        case geofenceViolationRate = "geofence_violation_rate"
        case complianceViolationRate = "compliance_violation_rate"
        case mileageAccuracy = "mileage_accuracy"
        case calculatedAt = "calculated_at"
        case geofenceEventCount = "geofence_event_count"
        case speedingEventCount = "speeding_event_count"
    }
}

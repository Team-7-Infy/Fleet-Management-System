import Foundation

struct DriverScore: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var driverId: UUID
    var overallScore: Double
    var inspectionFalseRate: Double?
    var geofenceViolationRate: Double?
    var complianceViolationRate: Double?
    var mileageAccuracy: Double?
    var calculatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case driverId = "driver_id"
        case overallScore = "overall_score"
        case inspectionFalseRate = "inspection_false_rate"
        case geofenceViolationRate = "geofence_violation_rate"
        case complianceViolationRate = "compliance_violation_rate"
        case mileageAccuracy = "mileage_accuracy"
        case calculatedAt = "calculated_at"
    }
}

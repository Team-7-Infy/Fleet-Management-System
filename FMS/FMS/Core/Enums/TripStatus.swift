import Foundation

enum TripStatus: String, Codable, CaseIterable {
    case scheduled = "scheduled"
    case pending = "pending"
    case accepted = "accepted"
    case rejectionPending = "rejection_pending"
    case rejected = "rejected"
    case inProgress = "in_progress"
    case completed = "completed"
    case cancelled = "cancelled"
}

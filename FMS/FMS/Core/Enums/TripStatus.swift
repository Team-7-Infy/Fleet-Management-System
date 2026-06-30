import Foundation

enum TripStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case accepted = "accepted"
    case rejectionPending = "rejection_pending"
    case rejected = "rejected"
    case inProgress = "in_progress"
    case completed = "completed"
}

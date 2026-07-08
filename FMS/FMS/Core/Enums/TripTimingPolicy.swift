import Foundation

enum TripTimingPolicy {
    static let preTripInspectionWindow: TimeInterval = 3 * 3600
    static let startTripWindow: TimeInterval = 1 * 3600
    static let postTripInspectionDeadline: TimeInterval = 2 * 3600
    static let cancellationLockWindow: TimeInterval = 24 * 3600
}

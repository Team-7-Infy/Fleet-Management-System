import Foundation

protocol ActivityServicing {
    func recentActivity() async throws -> [Activity]
    func logActivity(_ activity: Activity) async throws
}

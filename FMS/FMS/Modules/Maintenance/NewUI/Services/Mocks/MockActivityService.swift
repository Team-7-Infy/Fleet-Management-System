import Foundation

class MockActivityService: ActivityServicing {
    private var internalActivities: [Activity] = PreviewData.activities
    
    func recentActivity() async throws -> [Activity] {
        internalActivities.sorted(by: { $0.date > $1.date })
    }
    
    func logActivity(_ activity: Activity) async throws {
        internalActivities.append(activity)
    }
}

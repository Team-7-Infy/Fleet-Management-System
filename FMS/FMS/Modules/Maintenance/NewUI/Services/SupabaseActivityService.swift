import Foundation

final class SupabaseActivityService: ActivityServicing {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func recentActivity() async throws -> [Activity] {
        []
    }

    func logActivity(_ activity: Activity) async throws {
    }
}

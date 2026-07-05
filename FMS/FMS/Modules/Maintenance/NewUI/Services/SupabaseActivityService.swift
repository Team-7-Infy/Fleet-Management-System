import Foundation
import Supabase

final class SupabaseActivityService: ActivityServicing {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func recentActivity() async throws -> [Activity] {
        let tasks: [WorkOrder] = try await client
            .from("maintenance_task")
            .select("*,task_vehicles(vin)")
            .order("completedat", ascending: false)
            .limit(10)
            .execute()
            .value
            
        return tasks.map { task in
            Activity(
                id: task.id.uuidString,
                title: task.title,
                subtitle: "Task " + task.status.rawValue,
                date: {
                    if let dateStr = task.completedAt {
                        let isoFormatter = ISO8601DateFormatter()
                        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        if let d = isoFormatter.date(from: dateStr) { return d }
                    }
                    return task.dueDate
                }(),
                status: task.status,
                elapsedTime: task.elapsedTime ?? 0,
                vehicleType: "Car" // Would need a join with vehicles table for real type
            )
        }
    }

    func logActivity(_ activity: Activity) async throws {
    }
}

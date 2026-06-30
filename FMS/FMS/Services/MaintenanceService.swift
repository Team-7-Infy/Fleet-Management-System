import Foundation
import Supabase

private let dateOnlyParser: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.timeZone = TimeZone(secondsFromGMT: 0)
    f.locale = Locale(identifier: "en_US_POSIX")
    return f
}()

final actor MaintenanceService: MaintenanceServiceProtocol {
    private let supabase: SupabaseServiceProtocol

    init(supabase: SupabaseServiceProtocol) {
        self.supabase = supabase
    }

    func fetchTasks() async throws -> [MaintenanceTask] {
        try await supabase.client
            .from("maintenance_task")
            .select()
            .execute()
            .value
    }

    func fetchTasksForPersonnel(id: UUID) async throws -> [MaintenanceTask] {
        struct TaskRow: Decodable, Hashable {
            let taskid: UUID
            let description: String
            let scheduleddate: String
            let scheduledby: UUID?
            let executedby: UUID?
            let isurgent: Bool
            let status: String
        }
        let params: [String: AnyJSON] = ["p_personnel_id": .string(id.uuidString)]
        let rows: [TaskRow] = try await supabase.client
            .rpc("get_tasks_for_personnel", params: params)
            .execute()
            .value
        return rows.map { row in
            MaintenanceTask(
                id: row.taskid,
                description: row.description,
                scheduledDate: DateOnly(wrappedValue: dateOnlyParser.date(from: row.scheduleddate) ?? Date()),
                isUrgent: row.isurgent,
                scheduledBy: row.scheduledby,
                executedBy: row.executedby,
                status: MaintenanceTaskStatus(rawValue: row.status) ?? .scheduled
            )
        }
    }

    func fetchTask(id: UUID) async throws -> MaintenanceTask {
        try await supabase.client
            .from("maintenance_task")
            .select()
            .eq("taskid", value: id.uuidString)
            .single()
            .execute()
            .value
    }

    func createTask(_ task: MaintenanceTask) async throws -> MaintenanceTask {
        try await supabase.client
            .from("maintenance_task")
            .insert(task, returning: .representation)
            .select()
            .single()
            .execute()
            .value
    }

    func updateTask(_ task: MaintenanceTask) async throws -> MaintenanceTask {
        try await supabase.client
            .from("maintenance_task")
            .update(task, returning: .representation)
            .eq("taskid", value: task.id.uuidString)
            .select()
            .single()
            .execute()
            .value
    }

    func deleteTask(id: UUID) async throws {
        try await supabase.client
            .from("maintenance_task")
            .delete()
            .eq("taskid", value: id.uuidString)
            .execute()
    }

    func updateTaskStatus(id: UUID, status: MaintenanceTaskStatus) async throws {
        try await supabase.client
            .from("maintenance_task")
            .update(["status": status.rawValue])
            .eq("taskid", value: id.uuidString)
            .execute()
    }

    func assignPersonnel(taskId: UUID, personnelId: UUID) async throws {
        try await supabase.client
            .from("maintenance_task")
            .update(["executedby": personnelId.uuidString, "status": MaintenanceTaskStatus.assigned.rawValue])
            .eq("taskid", value: taskId.uuidString)
            .execute()
    }

    func fetchTaskParts(taskId: UUID) async throws -> [MaintenanceTaskPart] {
        try await supabase.client
            .from("maintenance_task_parts")
            .select()
            .eq("taskid", value: taskId.uuidString)
            .execute()
            .value
    }

    func addTaskPart(_ taskPart: MaintenanceTaskPart) async throws {
        try await supabase.client
            .from("maintenance_task_parts")
            .insert(taskPart)
            .execute()
    }

    func removeTaskPart(taskId: UUID, partId: UUID) async throws {
        try await supabase.client
            .from("maintenance_task_parts")
            .delete()
            .eq("taskid", value: taskId.uuidString)
            .eq("partid", value: partId.uuidString)
            .execute()
    }

    func fetchTaskVehicles(taskId: UUID) async throws -> [TaskVehicle] {
        try await supabase.client
            .from("task_vehicles")
            .select()
            .eq("taskid", value: taskId.uuidString)
            .execute()
            .value
    }

    func addTaskVehicle(_ taskVehicle: TaskVehicle) async throws {
        try await supabase.client
            .from("task_vehicles")
            .insert(taskVehicle)
            .execute()
    }

    func removeTaskVehicle(taskId: UUID, vin: UUID) async throws {
        try await supabase.client
            .from("task_vehicles")
            .delete()
            .eq("taskid", value: taskId.uuidString)
            .eq("vin", value: vin.uuidString)
            .execute()
    }
}

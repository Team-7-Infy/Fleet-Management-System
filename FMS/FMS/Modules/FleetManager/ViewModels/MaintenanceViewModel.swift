import Foundation
import Combine

@MainActor
final class MaintenanceViewModel: ObservableObject {
    @Published private(set) var tasks: [MaintenanceTask] = []
    @Published private(set) var taskVehicles: [UUID: [TaskVehicle]] = [:]
    @Published private(set) var taskParts: [UUID: [MaintenanceTaskPart]] = [:]
    @Published var isLoading = false
    @Published var successMessage: String?
    @Published var errorMessage: String?

    private let maintenanceService: MaintenanceServiceProtocol
    private let vehicleService: VehicleServiceProtocol
    private let workOrderAssignmentService: WorkOrderAssignmentServiceProtocol
    private let notificationService: NotificationServiceProtocol
    private let userManagementService: UserManagementServiceProtocol

    init(
        maintenanceService: MaintenanceServiceProtocol,
        vehicleService: VehicleServiceProtocol,
        workOrderAssignmentService: WorkOrderAssignmentServiceProtocol,
        notificationService: NotificationServiceProtocol,
        userManagementService: UserManagementServiceProtocol
    ) {
        self.maintenanceService = maintenanceService
        self.vehicleService = vehicleService
        self.workOrderAssignmentService = workOrderAssignmentService
        self.notificationService = notificationService
        self.userManagementService = userManagementService
    }

    var openTasks: [MaintenanceTask] {
        tasks.filter { $0.status != .completed && $0.status != .verified && $0.status != .closed && $0.status != .fake }
    }

    func getNextLeastLoadedAssigneeId() async -> UUID? {
        do {
            return try await maintenanceService.getNextLeastLoadedAssignee()
        } catch {
            print("Failed to get next least loaded assignee: \(error)")
            return nil
        }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let fetchedTasks = try await maintenanceService.fetchTasks()
                .sorted { $0.scheduledDate.date < $1.scheduledDate.date }
            var fetchedTaskVehicles: [UUID: [TaskVehicle]] = [:]
            var fetchedTaskParts: [UUID: [MaintenanceTaskPart]] = [:]

            for task in fetchedTasks {
                do {
                    fetchedTaskVehicles[task.id] = try await maintenanceService.fetchTaskVehicles(taskId: task.id)
                } catch {
                    print("Error fetching task vehicles for task \(task.id): \(error)")
                    fetchedTaskVehicles[task.id] = []
                }
                
                do {
                    fetchedTaskParts[task.id] = try await maintenanceService.fetchTaskParts(taskId: task.id)
                } catch {
                    print("Error fetching task parts for task \(task.id): \(error)")
                    fetchedTaskParts[task.id] = []
                }
            }

            tasks = fetchedTasks
            taskVehicles = fetchedTaskVehicles
            taskParts = fetchedTaskParts
            errorMessage = nil
        } catch is CancellationError {
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createTask(form: FleetManagerMaintenanceTaskForm) async -> Bool {
        guard form.isValid else {
            errorMessage = "Add a maintenance description."
            successMessage = nil
            return false
        }

        do {
            let task = try await maintenanceService.createTask(form.makeTask())

            if let vehicleId = form.vehicleId {
                let taskVehicle = TaskVehicle(taskId: task.id, vin: vehicleId)
                try await maintenanceService.addTaskVehicle(taskVehicle)
                taskVehicles[task.id] = [taskVehicle]
                let vehicle = try await vehicleService.fetchVehicle(id: vehicleId)
                var updatedVehicle = vehicle
                updatedVehicle.status = .inMaintenance
                _ = try await vehicleService.updateVehicle(updatedVehicle)
            }

            if task.executedBy == nil {
                if let best = try? await workOrderAssignmentService.findBestPersonnel() {
                    try await maintenanceService.assignPersonnel(taskId: task.id, personnelId: best.id)
                    if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                        tasks[idx].executedBy = best.id
                        tasks[idx].status = .assigned
                    }
                    await sendAssignmentNotifications(task: task, personnel: best, title: task.title ?? "Work Order")
                } else {
                    let fmUsers = (try? await userManagementService.fetchUsers().filter { $0.role == .fleetManager }) ?? []
                    for fm in fmUsers {
                        let note = AppNotification(
                            id: UUID(),
                            title: "Work Order Unassigned",
                            message: "No available maintenance personnel. Task '\(task.title ?? task.description)' remains unassigned.",
                            type: "work_order_assigned",
                            isRead: false,
                            referenceId: task.id,
                            recipientId: fm.id,
                            createdAt: Date()
                        )
                        _ = try? await notificationService.createNotification(note)
                    }
                }
            }

            tasks.insert(task, at: 0)
            taskParts[task.id] = []
            sortTasks()
            successMessage = "Maintenance task scheduled."
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            successMessage = nil
            return false
        }
    }

    private func sendAssignmentNotifications(task: MaintenanceTask, personnel: MaintenancePersonnel, title: String) async {
        let users = (try? await userManagementService.fetchUsers()) ?? []

        if let personnelUser = users.first(where: { $0.id == personnel.userId }) {
            let note = AppNotification(
                id: UUID(),
                title: "New Work Order: \(title)",
                message: task.description,
                type: "work_order_assigned",
                isRead: false,
                referenceId: task.id,
                recipientId: personnelUser.id,
                createdAt: Date()
            )
            _ = try? await notificationService.createNotification(note)
        }

        let fmUsers = users.filter { $0.role == .fleetManager }
        for fm in fmUsers {
            let note = AppNotification(
                id: UUID(),
                title: "Work Order Assigned: \(title)",
                message: task.description,
                type: "work_order_assigned",
                isRead: false,
                referenceId: task.id,
                recipientId: fm.id,
                createdAt: Date()
            )
            _ = try? await notificationService.createNotification(note)
        }
    }

    func updateStatus(_ task: MaintenanceTask, status: MaintenanceTaskStatus) async {
        do {
            try await maintenanceService.updateTaskStatus(id: task.id, status: status)
            if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[index].status = status
            }
            successMessage = "Task marked \(status.title.lowercased())."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            successMessage = nil
        }
    }

    func assignPersonnel(task: MaintenanceTask, personnelId: UUID) async {
        do {
            try await maintenanceService.assignPersonnel(taskId: task.id, personnelId: personnelId)
            if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[index].executedBy = personnelId
                tasks[index].status = .assigned
            }
            successMessage = "Task assigned."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            successMessage = nil
        }
    }

    func delete(_ task: MaintenanceTask) async {
        do {
            try await maintenanceService.deleteTask(id: task.id)
            tasks.removeAll { $0.id == task.id }
            successMessage = "Task deleted."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            successMessage = nil
        }
    }

    func vehicles(for task: MaintenanceTask) -> [TaskVehicle] {
        taskVehicles[task.id] ?? []
    }

    func parts(for task: MaintenanceTask) -> [MaintenanceTaskPart] {
        taskParts[task.id] ?? []
    }

    private func sortTasks() {
        tasks.sort { $0.scheduledDate.date < $1.scheduledDate.date }
    }
}

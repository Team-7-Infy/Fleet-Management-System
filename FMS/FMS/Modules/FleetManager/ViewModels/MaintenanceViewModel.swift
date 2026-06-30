import Foundation
import Combine

@MainActor
final class MaintenanceViewModel: ObservableObject {
    @Published private(set) var tasks: [MaintenanceTask] = []
    @Published var isLoading = false
    @Published var successMessage: String?
    @Published var errorMessage: String?

    private let maintenanceService: MaintenanceServiceProtocol
    private let vehicleService: VehicleServiceProtocol

    init(maintenanceService: MaintenanceServiceProtocol, vehicleService: VehicleServiceProtocol) {
        self.maintenanceService = maintenanceService
        self.vehicleService = vehicleService
    }

    var openTasks: [MaintenanceTask] {
        tasks.filter { $0.status != .completed }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            tasks = try await maintenanceService.fetchTasks()
                .sorted { $0.scheduledDate.date < $1.scheduledDate.date }
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
                try await maintenanceService.addTaskVehicle(TaskVehicle(taskId: task.id, vin: vehicleId))
                let vehicle = try await vehicleService.fetchVehicle(id: vehicleId)
                var updatedVehicle = vehicle
                updatedVehicle.status = .maintenance
                _ = try await vehicleService.updateVehicle(updatedVehicle)
            }

            tasks.insert(task, at: 0)
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

    private func sortTasks() {
        tasks.sort { $0.scheduledDate.date < $1.scheduledDate.date }
    }
}

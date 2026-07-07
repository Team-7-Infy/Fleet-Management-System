import Foundation

final actor WorkOrderAssignmentService: WorkOrderAssignmentServiceProtocol {
    private let userManagementService: UserManagementServiceProtocol
    private let maintenanceService: MaintenanceServiceProtocol

    init(
        userManagementService: UserManagementServiceProtocol,
        maintenanceService: MaintenanceServiceProtocol
    ) {
        self.userManagementService = userManagementService
        self.maintenanceService = maintenanceService
    }

    func findBestPersonnel() async throws -> MaintenancePersonnel? {
        let allPersonnel = try await userManagementService.fetchMaintenancePersonnel()
        let activePersonnel = allPersonnel.filter { $0.status == .active }
        guard !activePersonnel.isEmpty else { return nil }

        let users = try await userManagementService.fetchUsers()

        let eligiblePersonnel = activePersonnel.filter { personnel in
            guard let user = users.first(where: { $0.id == personnel.userId }) else { return false }
            return user.isActive && user.deletedAt == nil
        }
        guard !eligiblePersonnel.isEmpty else { return nil }

        var workloads: [(personnel: MaintenancePersonnel, openCount: Int)] = []
        for personnel in eligiblePersonnel {
            if let tasks = try? await maintenanceService.fetchTasksForPersonnel(id: personnel.id) {
                let openCount = tasks.filter { $0.status.isOpen }.count
                workloads.append((personnel, openCount))
            }
        }

        workloads.sort { a, b in
            if a.openCount != b.openCount { return a.openCount < b.openCount }
            return a.personnel.id.uuidString < b.personnel.id.uuidString
        }

        return workloads.first?.personnel
    }
}

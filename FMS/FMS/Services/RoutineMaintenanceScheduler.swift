import Foundation

struct RoutineMaintenanceScheduler {
    static func checkAndSchedule(vehicle: Vehicle, services: AppServices) async {
        do {
            let allTasks = try await services.maintenanceService.fetchTasks()

            let taskLinks = (try? await services.vehicleService.fetchTaskVehicles()) ?? []
            let vehicleTaskIds = Set(taskLinks.filter { $0.vin == vehicle.id }.map(\.taskId))

            let hasOpenTask = allTasks.contains { t in
                vehicleTaskIds.contains(t.id) && t.status.isOpen
            }
            if hasOpenTask {
                return
            }

            let completedTasks = allTasks.filter { vehicleTaskIds.contains($0.id) && $0.status == .completed }

            let lastCompletedDate = completedTasks.compactMap(\.completedAt).max() ?? vehicle.addedToFleetAt ?? Date()
            let monthsSince = Calendar.current.dateComponents([.month], from: lastCompletedDate, to: Date()).month ?? 0
            let timeDue: Bool
            if let monthInterval = vehicle.maintenanceMonthInterval, monthInterval > 0 {
                timeDue = monthsSince >= monthInterval
            } else {
                timeDue = false
            }

            let odoDue: Bool
            if let kmInterval = vehicle.maintenanceKmInterval, kmInterval > 0 {
                let threshold = (completedTasks.count + 1) * kmInterval
                odoDue = (vehicle.odometer ?? 0) >= Double(threshold)
            } else {
                odoDue = false
            }

            if timeDue || odoDue {
                let assigneeId = try await services.maintenanceService.getNextLeastLoadedAssignee()

                let reason = timeDue ? "Time interval of \(vehicle.maintenanceMonthInterval ?? 0) months exceeded" : "Odometer limit of \(vehicle.maintenanceKmInterval ?? 0) km reached"
                let description = "Automated routine maintenance scheduled for vehicle \(vehicle.licencePlate) (\(vehicle.make) \(vehicle.model)). Reason: \(reason)."

                let task = MaintenanceTask(
                    id: UUID(),
                    title: "Routine Maintenance - \(vehicle.licencePlate)",
                    description: description,
                    scheduledDate: DateOnly(wrappedValue: Date()),
                    isUrgent: false,
                    scheduledBy: nil,
                    executedBy: assigneeId,
                    status: assigneeId != nil ? .assigned : .scheduled,
                    reportedDate: Date()
                )

                _ = try await services.maintenanceService.createTask(task)

                let link = TaskVehicle(taskId: task.id, vin: vehicle.id)
                try await services.maintenanceService.addTaskVehicle(link)

                if let assigneeId = assigneeId {
                    let allP = (try? await services.userManagementService.fetchMaintenancePersonnel()) ?? []
                    if let personnel = allP.first(where: { $0.id == assigneeId }) {
                        let users = (try? await services.userManagementService.fetchUsers()) ?? []
                        if let personnelUser = users.first(where: { $0.id == personnel.userId }) {
                            let note = AppNotification(
                                id: UUID(),
                                title: "New Work Order: Routine Maintenance",
                                message: description,
                                type: "work_order_assigned",
                                isRead: false,
                                referenceId: task.id,
                                recipientId: personnelUser.id,
                                createdAt: Date()
                            )
                            _ = try? await services.notificationService.createNotification(note)
                        }
                    }
                }
            }
        } catch {
            print("Failed to run RoutineMaintenanceScheduler: \(error)")
        }
    }
}

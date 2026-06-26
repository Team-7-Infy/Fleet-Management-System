//
//  MaintenanceServiceProtocol.swift
//  FMS
//
//  Created by Veer on 26/06/26.
//

import Foundation


protocol MaintenanceServiceProtocol: AnyObject, Sendable {
    func fetchTasks() async throws -> [MaintenanceTask]
    func fetchTask(id: UUID) async throws -> MaintenanceTask
    func createTask(_ task: MaintenanceTask) async throws -> MaintenanceTask
    func updateTask(_ task: MaintenanceTask) async throws -> MaintenanceTask
    func deleteTask(id: UUID) async throws
    func updateTaskStatus(id: UUID, status: MaintenanceTaskStatus) async throws
    func assignPersonnel(taskId: UUID, personnelId: UUID) async throws

    func fetchTaskParts(taskId: UUID) async throws -> [MaintenanceTaskPart]
    func addTaskPart(_ taskPart: MaintenanceTaskPart) async throws
    func removeTaskPart(taskId: UUID, partId: UUID) async throws

    func fetchTaskVehicles(taskId: UUID) async throws -> [TaskVehicle]
    func addTaskVehicle(_ taskVehicle: TaskVehicle) async throws
    func removeTaskVehicle(taskId: UUID, vin: UUID) async throws
}

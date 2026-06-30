//
//  UserManagementServiceProtocol.swift
//  FMS
//
//  Created by Veer on 26/06/26.
//

import Foundation


protocol UserManagementServiceProtocol: AnyObject, Sendable {
    func fetchUsers() async throws -> [User]
    func createUser(_ user: User) async throws -> User
    func updateUser(_ user: User) async throws -> User
    func deleteUser(id: UUID) async throws
    func deleteDriverByUserId(id: UUID) async throws
    func deleteMaintenancePersonnelByUserId(id: UUID) async throws
    func deleteFleetManagerByUserId(id: UUID) async throws

    func fetchDrivers() async throws -> [Driver]
    func createDriver(_ driver: Driver) async throws -> Driver

    func fetchMaintenancePersonnel() async throws -> [MaintenancePersonnel]
    func createMaintenancePersonnel(_ personnel: MaintenancePersonnel) async throws -> MaintenancePersonnel

    func fetchFleetManagers() async throws -> [FleetManager]
    func createFleetManager(_ manager: FleetManager) async throws -> FleetManager
}

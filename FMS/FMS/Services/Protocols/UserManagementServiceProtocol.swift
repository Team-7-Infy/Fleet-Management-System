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
    func setUserActive(id: UUID, isActive: Bool) async throws

    func fetchDrivers() async throws -> [Driver]
    func createDriver(_ driver: Driver) async throws -> Driver

    func fetchMaintenancePersonnel() async throws -> [MaintenancePersonnel]
    func createMaintenancePersonnel(_ personnel: MaintenancePersonnel) async throws -> MaintenancePersonnel
}

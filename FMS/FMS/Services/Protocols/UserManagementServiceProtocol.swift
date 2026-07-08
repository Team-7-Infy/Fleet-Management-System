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
    func updateDriverProfile(userId: UUID, licenceNumber: String, vehicleType: String) async throws
    func updateDriverStatus(driverId: UUID, status: String) async throws
    func bulkUpdateDriverStatuses(updates: [(driverId: UUID, status: String)]) async throws
    func updateMaintenancePersonnelStatus(personnelId: UUID, status: String) async throws
    func bulkUpdateMaintenancePersonnelStatuses(updates: [(personnelId: UUID, status: String)]) async throws

    func fetchMaintenancePersonnel() async throws -> [MaintenancePersonnel]
    func createMaintenancePersonnel(_ personnel: MaintenancePersonnel) async throws -> MaintenancePersonnel

    func fetchFleetManagers() async throws -> [FleetManager]
    func createFleetManager(_ manager: FleetManager) async throws -> FleetManager

    func fetchDriverScore(driverId: UUID) async throws -> DriverScore?
    func fetchAllDriverScores() async throws -> [DriverScore]
    func calculateAndUpsertDriverScore(driverId: UUID) async throws -> DriverScore
    func fetchDriverSchedules(driverId: UUID) async throws -> [DriverSchedule]
    func fetchDriverSchedules(overlappingStart: Date, overlappingEnd: Date) async throws -> [DriverSchedule]
    func createDriverSchedule(_ schedule: DriverSchedule) async throws -> DriverSchedule
    func deleteDriverSchedule(id: UUID) async throws
}

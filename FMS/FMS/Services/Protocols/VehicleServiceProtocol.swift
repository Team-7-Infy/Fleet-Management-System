//
//  VehicleServiceProtocol.swift
//  FMS
//
//  Created by Veer on 26/06/26.
//

import Foundation


protocol VehicleServiceProtocol: AnyObject, Sendable {
    func fetchVehicles() async throws -> [Vehicle]
    func fetchVehicles(forDriverId: UUID) async throws -> [Vehicle]
    func fetchVehicle(id: UUID) async throws -> Vehicle
    func createVehicle(_ vehicle: Vehicle) async throws -> Vehicle
    func updateVehicle(_ vehicle: Vehicle) async throws -> Vehicle
    func deleteVehicle(id: UUID) async throws
    func assignDriver(vehicleId: UUID, driverId: UUID) async throws
    func unassignDriver(vehicleId: UUID) async throws
    func setOutOfService(vehicleId: UUID) async throws
    func fetchVehicleDocuments(vehicleId: UUID) async throws -> [VehicleDocument]
    func createVehicleDocument(_ document: VehicleDocument) async throws -> VehicleDocument
    func updateVehicleDocument(_ document: VehicleDocument) async throws -> VehicleDocument
    func deleteVehicleDocument(id: UUID) async throws
}

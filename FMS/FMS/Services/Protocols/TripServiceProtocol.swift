//
//  TripServiceProtocol.swift
//  FMS
//
//  Created by Veer on 26/06/26.
//
import SwiftUI

protocol TripServiceProtocol: AnyObject, Sendable {
    func fetchTrips() async throws -> [Trip]
    func fetchTrip(id: UUID) async throws -> Trip
    func createTrip(_ trip: Trip) async throws -> Trip
    func updateTrip(_ trip: Trip) async throws -> Trip
    func deleteTrip(id: UUID) async throws
    func updateTripStatus(id: UUID, status: TripStatus) async throws

    func fetchGeofence(tripId: UUID) async throws -> Geofence
    func upsertGeofence(_ geofence: Geofence) async throws -> Geofence

    func fetchDeviationAlerts(vehicleId: UUID) async throws -> [DeviationAlert]
    func fetchTelemetry(driverId: UUID) async throws -> [Telemetry]
    func logTelemetry(_ telemetry: Telemetry) async throws -> Telemetry
}

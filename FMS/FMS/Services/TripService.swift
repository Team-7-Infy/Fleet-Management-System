import Foundation
import Supabase



final actor TripService: TripServiceProtocol {
    private let supabase: SupabaseServiceProtocol

    init(supabase: SupabaseServiceProtocol) {
        self.supabase = supabase
    }

    func fetchTrips() async throws -> [Trip] {
        try await supabase.client
            .from("trips")
            .select()
            .execute()
            .value
    }

    func fetchTrips(forDriverId driverId: UUID) async throws -> [Trip] {
        try await supabase.client
            .from("trips")
            .select()
            .eq("driverid", value: driverId.uuidString)
            .execute()
            .value
    }

    func fetchTrip(id: UUID) async throws -> Trip {
        try await supabase.client
            .from("trips")
            .select()
            .eq("tripid", value: id.uuidString)
            .single()
            .execute()
            .value
    }

    func createTrip(_ trip: Trip) async throws -> Trip {
        try await supabase.client
            .from("trips")
            .insert(trip, returning: .representation)
            .select()
            .single()
            .execute()
            .value
    }

    func updateTrip(_ trip: Trip) async throws -> Trip {
        try await supabase.client
            .from("trips")
            .update(trip, returning: .representation)
            .eq("tripid", value: trip.id.uuidString)
            .select()
            .single()
            .execute()
            .value
    }

    func deleteTrip(id: UUID) async throws {
        try await supabase.client
            .from("trips")
            .delete()
            .eq("tripid", value: id.uuidString)
            .execute()
    }

    func updateTripStatus(id: UUID, status: TripStatus) async throws {
        try await supabase.client
            .from("trips")
            .update(["status": status.rawValue])
            .eq("tripid", value: id.uuidString)
            .execute()
    }

    func updateTripStatus(id: UUID, status: TripStatus, rejectionReason: String?) async throws {
        var update: [String: AnyJSON] = ["status": .string(status.rawValue)]
        if let reason = rejectionReason {
            update["rejection_reason"] = .string(reason)
        } else {
            update["rejection_reason"] = .null
        }
        try await supabase.client
            .from("trips")
            .update(update)
            .eq("tripid", value: id.uuidString)
            .execute()
    }

    func fetchGeofence(tripId: UUID) async throws -> Geofence {
        try await supabase.client
            .from("geofence")
            .select()
            .eq("tripid", value: tripId.uuidString)
            .single()
            .execute()
            .value
    }

    func upsertGeofence(_ geofence: Geofence) async throws -> Geofence {
        try await supabase.client
            .from("geofence")
            .upsert(geofence, returning: .representation)
            .select()
            .single()
            .execute()
            .value
    }

    func fetchDeviationAlerts(vehicleId: UUID) async throws -> [DeviationAlert] {
        try await supabase.client
            .from("deviation_alert")
            .select()
            .eq("vehicleid", value: vehicleId.uuidString)
            .execute()
            .value
    }

    func createDeviationAlert(_ alert: DeviationAlert) async throws -> DeviationAlert {
        try await supabase.client
            .from("deviation_alert")
            .insert(alert, returning: .representation)
            .select()
            .single()
            .execute()
            .value
    }

    func fetchRouteWaypoints(tripId: UUID) async throws -> [RouteWaypoint] {
        try await supabase.client
            .from("route_waypoints")
            .select()
            .eq("tripid", value: tripId.uuidString)
            .order("sequenceorder", ascending: true)
            .execute()
            .value
    }

    func fetchTelemetry(driverId: UUID) async throws -> [Telemetry] {
        try await supabase.client
            .from("telemetry_log")
            .select()
            .eq("driverid", value: driverId.uuidString)
            .order("timestamp", ascending: false)
            .execute()
            .value
    }

    func logTelemetry(_ telemetry: Telemetry) async throws -> Telemetry {
        try await supabase.client
            .from("telemetry_log")
            .insert(telemetry, returning: .representation)
            .select()
            .single()
            .execute()
            .value
    }

    nonisolated func subscribeToTrips(forDriverId driverId: UUID) -> AsyncStream<Void> {
        AsyncStream { continuation in
            let channelName = "trips-realtime-dashboard-\(driverId.uuidString.lowercased())"
            let channel = supabase.client.channel(channelName)
            
            let inserts = channel.postgresChange(
                InsertAction.self,
                schema: "public",
                table: "trips"
            )
            let updates = channel.postgresChange(
                UpdateAction.self,
                schema: "public",
                table: "trips"
            )
            
            let task = Task {
                await channel.subscribe()
                
                Task {
                    for await change in inserts {
                        let record = change.record
                        do {
                            let jsonData = try JSONEncoder().encode(record)
                            let trip = try SharedDecoder.json.decode(Trip.self, from: jsonData)
                            if trip.driverId == driverId {
                                continuation.yield(())
                            }
                        } catch {
                            print("Error decoding dashboard Realtime trip insert: \(error)")
                        }
                    }
                }
                
                Task {
                    for await change in updates {
                        let record = change.record
                        do {
                            let jsonData = try JSONEncoder().encode(record)
                            let trip = try SharedDecoder.json.decode(Trip.self, from: jsonData)
                            if trip.driverId == driverId {
                                continuation.yield(())
                            }
                        } catch {
                            print("Error decoding dashboard Realtime trip update: \(error)")
                        }
                    }
                }
            }
            
            continuation.onTermination = { @Sendable _ in
                task.cancel()
                Task {
                    await channel.unsubscribe()
                }
            }
        }
    }
}

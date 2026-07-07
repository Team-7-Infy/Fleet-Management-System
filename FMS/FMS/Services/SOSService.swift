import Foundation
import Supabase

final actor SOSService: SOSServiceProtocol {
    private let supabase: SupabaseServiceProtocol

    init(supabase: SupabaseServiceProtocol) {
        self.supabase = supabase
    }

    func createEvent(_ event: SOSEvent) async throws -> SOSEvent {
        try await supabase.client
            .from("sos_events")
            .insert(event, returning: .representation)
            .select()
            .single()
            .execute()
            .value
    }

    func fetchEvents(driverId: UUID) async throws -> [SOSEvent] {
        try await supabase.client
            .from("sos_events")
            .select()
            .eq("driver_id", value: driverId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func fetchPendingEvents() async throws -> [SOSEvent] {
        try await supabase.client
            .from("sos_events")
            .select()
            .eq("status", value: "pending")
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func updateStatus(id: UUID, status: SOSEvent.SOSStatus, resolvedBy: UUID? = nil, notes: String? = nil) async throws {
        var payload: [String: AnyJSON] = ["status": AnyJSON.string(status.rawValue)]
        if let resolvedBy {
            payload["resolved_by"] = AnyJSON.string(resolvedBy.uuidString)
            payload["resolved_at"] = AnyJSON.string(ISO8601DateFormatter().string(from: Date()))
        }
        if let notes {
            payload["notes"] = AnyJSON.string(notes)
        }
        try await supabase.client
            .from("sos_events")
            .update(payload)
            .eq("id", value: id.uuidString)
            .execute()
    }

    nonisolated func subscribeToEvents(for driverId: UUID) -> AsyncStream<SOSEvent> {
        AsyncStream { continuation in
            let channelName = "sos-events-\(driverId.uuidString)"
            let channel = supabase.client.channel(channelName)

            let inserts = channel.postgresChange(
                InsertAction.self,
                schema: "public",
                table: "sos_events"
            )
            let updates = channel.postgresChange(
                UpdateAction.self,
                schema: "public",
                table: "sos_events"
            )

            let task = Task {
                do {
                    await channel.subscribe()

                    Task {
                        for await change in inserts {
                            let record = change.record
                            do {
                                let jsonData = try JSONEncoder().encode(record)
                                let event = try SharedDecoder.json.decode(SOSEvent.self, from: jsonData)
                                if event.driverId == driverId {
                                    continuation.yield(event)
                                }
                            } catch {
                                print("Error decoding Realtime SOS insert: \(error)")
                            }
                        }
                    }

                    Task {
                        for await change in updates {
                            let record = change.record
                            do {
                                let jsonData = try JSONEncoder().encode(record)
                                let event = try SharedDecoder.json.decode(SOSEvent.self, from: jsonData)
                                if event.driverId == driverId {
                                    continuation.yield(event)
                                }
                            } catch {
                                print("Error decoding Realtime SOS update: \(error)")
                            }
                        }
                    }
                } catch {
                    print("SOS Realtime subscription error: \(error)")
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

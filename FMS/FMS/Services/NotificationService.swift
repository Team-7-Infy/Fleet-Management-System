import Foundation
import Supabase
import Realtime

final actor NotificationService: NotificationServiceProtocol {
    private let supabase: SupabaseServiceProtocol

    init(supabase: SupabaseServiceProtocol) {
        self.supabase = supabase
    }

    func fetchNotifications(for recipientId: UUID?, driverId: UUID?) async throws -> [AppNotification] {
        let query = supabase.client.from("notifications").select()
        if let recipientId {
            if let driverId {
                return try await query
                    .or("recipient_id.eq.\(recipientId.uuidString),recipient_id.eq.\(driverId.uuidString),recipient_id.is.null")
                    .order("created_at", ascending: false)
                    .execute()
                    .value
            } else {
                return try await query
                    .or("recipient_id.eq.\(recipientId.uuidString),recipient_id.is.null")
                    .order("created_at", ascending: false)
                    .execute()
                    .value
            }
        } else if let driverId {
            return try await query
                .or("recipient_id.eq.\(driverId.uuidString),recipient_id.is.null")
                .order("created_at", ascending: false)
                .execute()
                .value
        } else {
            return try await query
                .order("created_at", ascending: false)
                .execute()
                .value
        }
    }

    func markAsRead(id: UUID) async throws {
        try await supabase.client
            .from("notifications")
            .update(["is_read": true])
            .eq("id", value: id.uuidString)
            .execute()
    }

    func markAllAsRead(for recipientId: UUID?, driverId: UUID?) async throws {
        let query = try supabase.client.from("notifications").update(["is_read": true])
        if let recipientId {
            if let driverId {
                try await query
                    .or("recipient_id.eq.\(recipientId.uuidString),recipient_id.eq.\(driverId.uuidString),recipient_id.is.null")
                    .execute()
            } else {
                try await query
                    .or("recipient_id.eq.\(recipientId.uuidString),recipient_id.is.null")
                    .execute()
            }
        } else if let driverId {
            try await query
                .or("recipient_id.eq.\(driverId.uuidString),recipient_id.is.null")
                .execute()
        } else {
            try await query
                .execute()
        }
    }

    func subscribeToRealtime(for recipientId: UUID?, driverId: UUID?) -> AsyncStream<AppNotification> {
        AsyncStream { continuation in
            let channelIdString = recipientId?.uuidString ?? driverId?.uuidString ?? "all"
            let channelName = "notifications-realtime-\(channelIdString)"
            let channel = supabase.client.channel(channelName)
            
            let changes = channel.postgresChange(
                InsertAction.self,
                schema: "public",
                table: "notifications"
            )
            
            let task = Task {
                do {
                    await channel.subscribe()
                    
                    for await change in changes {
                        let record = change.record
                        do {
                            let jsonData = try JSONEncoder().encode(record)
                            let notification = try SharedDecoder.json.decode(AppNotification.self, from: jsonData)
                            
                            if let recipientId {
                                if let driverId {
                                    if notification.recipientId == recipientId || notification.recipientId == driverId || notification.recipientId == nil {
                                        continuation.yield(notification)
                                    }
                                } else {
                                    if notification.recipientId == recipientId || notification.recipientId == nil {
                                        continuation.yield(notification)
                                    }
                                }
                            } else if let driverId {
                                if notification.recipientId == driverId || notification.recipientId == nil {
                                    continuation.yield(notification)
                                }
                            } else {
                                continuation.yield(notification)
                            }
                        } catch {
                            print("Error decoding Realtime notification: \(error)")
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

    nonisolated func subscribeToTripsRealtime(forDriverId driverId: UUID) -> AsyncStream<Trip> {
        AsyncStream { continuation in
            let channelName = "trips-realtime-\(driverId.uuidString)"
            let channel = supabase.client.channel(channelName)
            
            let changes = channel.postgresChange(
                AnyAction.self,
                schema: "public",
                table: "trips"
            )
            
            let task = Task {
                await channel.subscribe()
                
                for await change in changes {
                    var record: [String: AnyJSON]? = nil
                    switch change {
                    case .insert(let action):
                        record = action.record
                    case .update(let action):
                        record = action.record
                    case .delete:
                        break
                    }
                    
                    guard let record = record else { continue }
                    
                    do {
                        let jsonData = try JSONEncoder().encode(record)
                        let trip = try SharedDecoder.json.decode(Trip.self, from: jsonData)
                        if trip.driverId == driverId {
                            continuation.yield(trip)
                        }
                    } catch {
                        print("Error decoding Realtime trip change: \(error)")
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

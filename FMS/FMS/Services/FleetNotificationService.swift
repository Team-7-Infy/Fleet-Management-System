import Foundation
import Supabase

final actor FleetNotificationService: FleetNotificationServiceProtocol {
    private let supabase: SupabaseServiceProtocol

    init(supabase: SupabaseServiceProtocol) {
        self.supabase = supabase
    }

    func fetchNotifications(recipientId: UUID) async throws -> [FleetNotification] {
        try await supabase.client
            .from("notifications")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func markNotificationRead(id: UUID, isRead: Bool) async throws {
        try await supabase.client
            .from("notifications")
            .update(["is_read": isRead])
            .eq("id", value: id.uuidString)
            .execute()
    }

    func markAllNotificationsRead(recipientId: UUID, category: FleetNotificationCategory?) async throws {
        if let category {
            try await supabase.client
                .from("notifications")
                .update(["is_read": true])
                .eq("recipient_id", value: recipientId.uuidString)
                .eq("type", value: category.rawValue)
                .execute()
        } else {
            try await supabase.client
                .from("notifications")
                .update(["is_read": true])
                .eq("recipient_id", value: recipientId.uuidString)
                .execute()
        }
    }
}

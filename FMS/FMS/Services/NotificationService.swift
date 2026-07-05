import Foundation
import Combine
import Supabase

@MainActor
final class NotificationService: ObservableObject {
    
    @Published var notifications: [AppNotification] = []
    @Published var unreadCount: Int = 0
    @Published var isLoading = false
    @Published var error: Error?
    
    private let supabase: SupabaseServiceProtocol
    private var realtimeChannel: RealtimeChannelV2?
    
    init(supabase: SupabaseServiceProtocol) {
        self.supabase = supabase
    }
    
    func fetchNotifications() async {
        isLoading = true
        error = nil
        
        do {
            // First, fetch the locally hidden/cleared notification IDs
            let hiddenIds = UserDefaults.standard.stringArray(forKey: "hidden_notifications") ?? []
            
            // Note: Since we are using RLS and recipient_id might be used for targeted notifications,
            // we filter by recipient_id.is.null or recipient_id.eq.userId depending on the user's role.
            guard let session = supabase.client.auth.currentSession else {
                throw URLError(.userAuthenticationRequired)
            }
            let userId = session.user.id
            
            struct UserRole: Decodable { let role: String }
            let userRecord: UserRole = try await supabase.client.from("users")
                .select("role")
                .eq("userid", value: userId)
                .single()
                .execute()
                .value
            
            var query = supabase.client.from("notifications")
                .select()
            
            if userRecord.role == "fleet_manager" {
                query = query.or("recipient_id.eq.\(userId.uuidString.lowercased()),recipient_id.is.null")
            } else {
                query = query.eq("recipient_id", value: userId.uuidString.lowercased())
            }
            
            let finalQuery = query
                .order("created_at", ascending: false)
                .limit(50)
            
            let fetched: [AppNotification] = try await finalQuery.execute().value
            
            // Filter out hidden ones
            // let visible = fetched.filter { !hiddenIds.contains($0.id.uuidString) }
            let visible = fetched
            
            self.notifications = visible
            self.updateUnreadCount()
            
            // Start listening for new ones
            Task {
                await setupRealtimeSubscription()
            }
        } catch {
            self.error = error
            print("Failed to fetch notifications: \(error)")
        }
        
        isLoading = false
    }
    
    func markAsRead(_ notification: AppNotification) async {
        guard !notification.isRead else { return }
        
        // Optimistic UI update
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            notifications[index].isRead = true
            updateUnreadCount()
        }
        
        do {
            try await supabase.client.from("notifications")
                .update(["is_read": true])
                .eq("id", value: notification.id)
                .execute()
        } catch {
            print("Failed to mark notification as read: \(error)")
            // Rollback optimistic update
            if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
                notifications[index].isRead = false
                updateUnreadCount()
            }
        }
    }
    
    func markAllAsRead() async {
        guard unreadCount > 0 else { return }
        
        let unreadIds = notifications.filter { !$0.isRead }.map { $0.id }
        
        // Optimistic UI update
        for i in 0..<notifications.count {
            notifications[i].isRead = true
        }
        updateUnreadCount()
        
        do {
            try await supabase.client.from("notifications")
                .update(["is_read": true])
                .in("id", values: unreadIds)
                .execute()
        } catch {
            print("Failed to mark all notifications as read: \(error)")
        }
    }
    
    func hideNotification(_ notification: AppNotification) {
        // Optimistic UI update
        notifications.removeAll(where: { $0.id == notification.id })
        updateUnreadCount()
        
        // Save to local user defaults
        var hiddenIds = UserDefaults.standard.stringArray(forKey: "hidden_notifications") ?? []
        hiddenIds.append(notification.id.uuidString)
        UserDefaults.standard.set(hiddenIds, forKey: "hidden_notifications")
    }
    
    private func updateUnreadCount() {
        unreadCount = notifications.filter { !$0.isRead }.count
    }
    
    private func setupRealtimeSubscription() async {
        guard realtimeChannel == nil else { return }
        
        let channel = supabase.client.channel("public:notifications")
        realtimeChannel = channel
        
        let changes = await channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "notifications"
        )
        
        do {
            // Fetch user role for realtime filtering
            let userId = self.supabase.client.auth.currentSession?.user.id
            struct UserRole: Decodable { let role: String }
            var isManager = false
            if let uid = userId {
                if let record: UserRole = try? await supabase.client.from("users").select("role").eq("userid", value: uid).single().execute().value {
                    isManager = (record.role == "fleet_manager")
                }
            }
            
            try await channel.subscribe()
            
            for await change in changes {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                do {
                    let data = try JSONSerialization.data(withJSONObject: change.record as Any)
                    let newNotification = try decoder.decode(AppNotification.self, from: data)
                    
                    let shouldShow = newNotification.recipientId == userId || (isManager && newNotification.recipientId == nil)
                    
                    if shouldShow {
                        await MainActor.run {
                            self.notifications.insert(newNotification, at: 0)
                            self.updateUnreadCount()
                        }
                    }
                } catch {
                    print("Failed to decode realtime notification: \(error)")
                }
            }
        } catch {
            print("Failed to subscribe to realtime channel: \(error)")
        }
    }
    
    deinit {
        Task { [weak realtimeChannel] in
            try? await realtimeChannel?.unsubscribe()
        }
    }
}

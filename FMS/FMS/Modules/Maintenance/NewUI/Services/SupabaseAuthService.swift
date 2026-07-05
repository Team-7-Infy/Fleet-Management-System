import Foundation
import Supabase

final class SupabaseAuthService: AuthServicing {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func currentUser() async throws -> UserProfile {
        guard let authUser = client.auth.currentUser else {
            throw AppError.networkUnavailable
        }
        let user: User = try await client
            .from("users")
            .select()
            .eq("userid", value: authUser.id.uuidString)
            .single()
            .execute()
            .value
        var profile = user.toUserProfile()
        // Look up the personnel ID if the user is maintenance personnel
        if user.role == .maintenancePersonnel {
            let personnel: [MaintenancePersonnel] = try await client
                .from("maintenance_personnel")
                .select()
                .eq("userid", value: authUser.id.uuidString)
                .execute()
                .value
            profile.personnelId = personnel.first?.id
        }
        return profile
    }

    func updateProfileImage(data: Data) async throws -> UserProfile {
        try await currentUser()
    }
    
    func updateProfile(firstName: String?, lastName: String?, contact: Int64?, address: String?) async throws -> UserProfile {
        guard let authUser = client.auth.currentUser else {
            throw AppError.networkUnavailable
        }
        
        struct UpdateProfilePayload: Encodable {
            let f_name: String?
            let l_name: String?
            let contact: Int64?
            let address: String?
        }
        
        let payload = UpdateProfilePayload(f_name: firstName, l_name: lastName, contact: contact, address: address)
        
        try await client
            .from("users")
            .update(payload)
            .eq("userid", value: authUser.id.uuidString)
            .execute()
            
        return try await currentUser()
    }
    
    func getUserProfile(by id: UUID) async throws -> UserProfile {
        // Try fetching fleet manager first
        let manager: FleetManager? = try? await client
            .from("fleet_manager")
            .select()
            .eq("managerid", value: id.uuidString)
            .single()
            .execute()
            .value
            
        let userId = manager?.userId ?? id
        
        let user: User = try await client
            .from("users")
            .select()
            .eq("userid", value: userId.uuidString)
            .single()
            .execute()
            .value
            
        return user.toUserProfile()
    }
}

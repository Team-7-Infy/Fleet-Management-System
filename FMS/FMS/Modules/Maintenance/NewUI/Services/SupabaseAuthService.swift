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
}

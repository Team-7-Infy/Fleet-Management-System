import Foundation
import Supabase
import UIKit

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

        if !user.isActive || user.deletedAt != nil {
            try? await client.auth.signOut()
            throw AppError.accountDisabled
        }

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
        guard let authUser = client.auth.currentUser else {
            throw AppError.networkUnavailable
        }

        let uploadData = compressedImageData(from: data)
        let bucketId = "maintenance"
        let path = "avatar-\(authUser.id.uuidString)-\(Int(Date().timeIntervalSince1970)).jpg"

        let publicURL = try client.storage
            .from(bucketId)
            .getPublicURL(path: path)
            .absoluteString

        let baseURL = EnvironmentConfig.supabaseURL
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        components.path = "/storage/v1/object/\(bucketId)/\(path)"
        guard let uploadURL = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.setValue("3600", forHTTPHeaderField: "cache-control")
        request.setValue("true", forHTTPHeaderField: "x-upsert")
        request.setValue(EnvironmentConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        if let token = try? await client.auth.session.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = uploadData

        let (_, urlResponse) = try await URLSession.shared.data(for: request)
        guard let httpResponse = urlResponse as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        // Update avatarurl in the users table
        struct AvatarPayload: Encodable {
            let avatarurl: String
        }
        try await client
            .from("users")
            .update(AvatarPayload(avatarurl: publicURL))
            .eq("userid", value: authUser.id.uuidString)
            .execute()

        return try await currentUser()
    }

    private func compressedImageData(from data: Data) -> Data {
        guard let image = UIImage(data: data),
              let compressed = image.jpegData(compressionQuality: 0.6) else {
            return data
        }
        return compressed
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

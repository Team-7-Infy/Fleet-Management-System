import Foundation

struct MockAuthService: AuthServicing {
    func currentUser() async throws -> UserProfile {
        PreviewData.currentUser
    }
    
    func updateProfileImage(data: Data) async throws -> UserProfile {
        var user = PreviewData.currentUser
        user.profileImageData = data
        return user
    }
    
    func updateProfile(firstName: String?, lastName: String?, contact: Int64?, address: String?) async throws -> UserProfile {
        return try await currentUser()
    }
    
    func getUserProfile(by id: UUID) async throws -> UserProfile {
        return PreviewData.currentUser
    }
}

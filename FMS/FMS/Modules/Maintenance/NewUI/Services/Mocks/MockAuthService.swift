import Foundation

struct MockAuthService: AuthServicing {
    func currentUser() async throws -> UserProfile {
        PreviewData.currentUser
    }
    
    func updateProfileImage(data: Data) async throws -> UserProfile {
        PreviewData.currentUser.profileImageData = data
        return PreviewData.currentUser
    }
}

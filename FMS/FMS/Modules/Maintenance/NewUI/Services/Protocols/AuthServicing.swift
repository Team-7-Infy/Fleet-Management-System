import Foundation

protocol AuthServicing {
    func currentUser() async throws -> UserProfile
    func updateProfileImage(data: Data) async throws -> UserProfile
}

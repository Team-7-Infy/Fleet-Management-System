import Foundation

protocol AuthServicing {
    func currentUser() async throws -> UserProfile
    func updateProfileImage(data: Data) async throws -> UserProfile
    func updateProfile(firstName: String?, lastName: String?, contact: Int64?, address: String?) async throws -> UserProfile
    func getUserProfile(by id: UUID) async throws -> UserProfile
}

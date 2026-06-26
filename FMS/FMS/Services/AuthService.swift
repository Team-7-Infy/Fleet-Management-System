import Foundation
import Supabase

final actor AuthService: AuthServiceProtocol {
    private let supabase: SupabaseServiceProtocol

    init(supabase: SupabaseServiceProtocol) {
        self.supabase = supabase
    }

    func signUp(email: String, password: String) async throws -> User {
        try await supabase.client.auth.signUp(email: email, password: password)
        let session = try await supabase.client.auth.session
        let user: User = try await supabase.client
            .from("users")
            .select()
            .eq("email", value: email)
            .single()
            .execute()
            .value
        return user
    }

    func signIn(email: String, password: String) async throws -> User {
        try await supabase.client.auth.signIn(email: email, password: password)
        let user: User = try await supabase.client
            .from("users")
            .select()
            .eq("email", value: email)
            .single()
            .execute()
            .value
        return user
    }

    func signOut() async throws {
        try await supabase.client.auth.signOut()
    }

    func currentSession() async throws -> User? {
        guard let authUser = supabase.client.auth.currentUser else { return nil }
        let user: User = try await supabase.client
            .from("users")
            .select()
            .eq("userid", value: authUser.id.uuidString)
            .single()
            .execute()
            .value
        return user
    }

    func deleteAccount() async throws {
        try await supabase.client.rpc("delete_account")
    }
}

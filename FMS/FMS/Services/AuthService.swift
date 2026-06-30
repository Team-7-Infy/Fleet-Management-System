import Foundation
import Supabase

enum AuthError: LocalizedError {
    case userNotFound
    case userNotCreated
    case functionError(String)
    case invalidUserID

    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "User not found. Please try signing up first."
        case .userNotCreated:
            return "Could not create user profile. Please try again."
        case let .functionError(detail):
            return "Server error: \(detail)"
        case .invalidUserID:
            return "Invalid response from server."
        }
    }
}

final actor AuthService: AuthServiceProtocol {
    private let supabase: SupabaseServiceProtocol

    init(supabase: SupabaseServiceProtocol) {
        self.supabase = supabase
    }

    func signUp(email: String, password: String) async throws -> User {
        let authResponse = try await supabase.client.auth.signUp(email: email, password: password)
        guard let authUser: Auth.User = (authResponse.user ?? supabase.client.auth.currentUser) else {
            throw AuthError.userNotFound
        }

        let newUser = User(
            id: authUser.id,
            email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            aadhar: "",
            contact: 0,
            role: .fleetManager,
            fName: "",
            lName: "",
            address: "",
            isActive: true,
            createdAt: Date(),
            firstTimeLogin: false
        )

        let createdUser: User = try await supabase.client
            .from("users")
            .insert(newUser, returning: .representation)
            .select()
            .single()
            .execute()
            .value

        let manager = FleetManager(id: UUID(), userId: createdUser.id)
        try await supabase.client
            .from("fleet_manager")
            .insert(manager)
            .execute()

        return createdUser
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

    func createAuthIdentity(email: String, password: String) async throws -> UUID {
        let authResponse = try await supabase.client.auth.signUp(email: email, password: password)
        guard let authUser = authResponse.user ?? supabase.client.auth.currentUser else {
            throw AuthError.userNotFound
        }
        return authUser.id
    }

    func inviteUser(email: String, password: String, displayName: String) async throws -> UUID {
        let functionURL = EnvironmentConfig.supabaseURL.appendingPathComponent("functions/v1/invite-user")

        var request = URLRequest(url: functionURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let session = supabase.client.auth.currentSession {
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        }

        let body = try JSONEncoder().encode([
            "email": email,
            "password": password,
            "displayName": displayName
        ])
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "unknown error"
            throw AuthError.functionError(errorBody)
        }

        struct InviteResponse: Decodable {
            let userId: String
        }
        let inviteResponse = try JSONDecoder().decode(InviteResponse.self, from: data)
        guard let uuid = UUID(uuidString: inviteResponse.userId) else {
            throw AuthError.invalidUserID
        }
        return uuid
    }

    func sendRecoveryOTP(email: String) async throws {
        let functionURL = EnvironmentConfig.supabaseURL.appendingPathComponent("functions/v1/send-recovery-otp")

        var request = URLRequest(url: functionURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = try JSONEncoder().encode(["email": email])
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.functionError("Invalid response")
        }

        struct OTPResponse: Decodable {
            let otpSent: Bool?
            let emailError: String?
            let error: String?
        }

        guard httpResponse.statusCode == 200,
              let otpResponse = try? JSONDecoder().decode(OTPResponse.self, from: data) else {
            if let errorBody = try? JSONDecoder().decode(OTPResponse.self, from: data),
               let error = errorBody.error {
                throw AuthError.functionError(error)
            }
            let body = String(data: data, encoding: .utf8) ?? "unknown error"
            throw AuthError.functionError(body)
        }

        guard otpResponse.otpSent == true else {
            throw AuthError.functionError(otpResponse.emailError ?? "Failed to send verification code")
        }
    }

    func verifyOTP(email: String, token: String) async throws {
        try await supabase.client.auth.verifyOTP(email: email, token: token, type: .recovery)
    }

    func updateUserPassword(password: String) async throws {
        try await supabase.client.auth.update(user: UserAttributes(password: password))
    }

    func markFirstTimeLoginComplete(userId: UUID) async throws {
        try await supabase.client
            .from("users")
            .update(["first_time_login": false])
            .eq("userid", value: userId.uuidString)
            .execute()
    }

    func forceUpdatePassword(userId: UUID, password: String) async throws {
        let functionURL = EnvironmentConfig.supabaseURL.appendingPathComponent("functions/v1/force-update-password")

        var request = URLRequest(url: functionURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let session = supabase.client.auth.currentSession {
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        }

        let body = try JSONEncoder().encode(["userId": userId.uuidString, "password": password])
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "unknown error"
            throw AuthError.functionError(errorBody)
        }
    }

    func deleteUserAuth(userId: UUID) async throws {
        let functionURL = EnvironmentConfig.supabaseURL.appendingPathComponent("functions/v1/delete-user")

        var request = URLRequest(url: functionURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let session = supabase.client.auth.currentSession {
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        }

        let body = try JSONEncoder().encode(["userId": userId.uuidString])
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "unknown error"
            throw AuthError.functionError(errorBody)
        }
    }

    func deleteAccount() async throws {
        try await supabase.client.rpc("delete_account").execute()
    }
}


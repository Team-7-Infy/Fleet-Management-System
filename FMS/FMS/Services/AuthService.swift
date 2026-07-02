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
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        try await supabase.client.auth.signIn(email: normalizedEmail, password: normalizedPassword)

        if let authUser = supabase.client.auth.currentUser {
            let user: User = try await supabase.client
                .from("users")
                .select()
                .eq("userid", value: authUser.id.uuidString)
                .single()
                .execute()
                .value
            return user
        }

        let user: User = try await supabase.client
            .from("users")
            .select()
            .eq("email", value: normalizedEmail)
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

    func completeFirstTimeProfile(
        user: User,
        name: String,
        email: String,
        contact: Int64,
        address: String,
        aadhar: String,
        avatarUrl: String?,
        licenceNumber: String?,
        vehicleType: String?
    ) async throws -> User {
        let normalizedName = UserProfileValidation.normalizedName(name)
        let normalizedEmail = UserProfileValidation.normalizedEmail(email)
        let normalizedContact = "\(contact)"
        let normalizedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedAadhaar = UserProfileValidation.normalizedAadhaar(aadhar)
        let trimmedAvatar = UserProfileValidation.normalizedURL(avatarUrl ?? "")

        guard UserProfileValidation.isValidName(normalizedName) else {
            throw AuthError.functionError("Enter a valid name using letters, spaces, apostrophes, or hyphens.")
        }

        guard UserProfileValidation.isValidEmail(normalizedEmail) else {
            throw AuthError.functionError("Enter a valid email address.")
        }

        guard UserProfileValidation.isValidContact(normalizedContact) else {
            throw AuthError.functionError("Contact must be a 10-digit mobile number starting with 6, 7, 8, or 9.")
        }

        if user.role == .driver || user.role == .maintenancePersonnel {
            guard UserProfileValidation.isValidAddress(normalizedAddress) else {
                throw AuthError.functionError("Address must be 5-160 characters and use only common address characters.")
            }

            guard UserProfileValidation.isValidAadhaar(normalizedAadhaar) else {
                throw AuthError.functionError("Aadhaar must be exactly 12 digits.")
            }
        }

        guard UserProfileValidation.isValidOptionalURL(trimmedAvatar) else {
            throw AuthError.functionError("Photo URL must start with http:// or https://.")
        }

        let nameParts = Self.nameParts(from: normalizedName)
        var userUpdate: [String: AnyJSON] = [
            "email": .string(normalizedEmail),
            "contact": .integer(Int(contact)),
            "f_name": .string(nameParts.first),
            "l_name": .string(nameParts.last),
            "address": .string(normalizedAddress),
            "aadhar": .string(normalizedAadhaar),
            "first_time_login": .bool(false)
        ]
        userUpdate["avatarurl"] = trimmedAvatar.isEmpty ? .null : .string(trimmedAvatar)

        try await supabase.client
            .from("users")
            .update(userUpdate)
            .eq("userid", value: user.id.uuidString)
            .execute()

        if user.role == .driver {
            let trimmedLicence = UserProfileValidation.normalizedLicenceNumber(licenceNumber ?? "")
            guard UserProfileValidation.isValidLicenceNumber(trimmedLicence, allowsPending: false) else {
                throw AuthError.functionError("Licence must look like DL-042026-7101 or MH12 2026 1234567.")
            }

            let trimmedVehicleType = vehicleType?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            let driverUpdate: [String: AnyJSON] = [
                "licencenum": .string(trimmedLicence),
                "vehicletype": .string(trimmedVehicleType.isEmpty ? "van" : trimmedVehicleType)
            ]

            try await supabase.client
                .from("drivers")
                .update(driverUpdate)
                .eq("userid", value: user.id.uuidString)
                .execute()
        }

        let updatedUser: User = try await supabase.client
            .from("users")
            .select()
            .eq("userid", value: user.id.uuidString)
            .single()
            .execute()
            .value

        return updatedUser
    }

    private static func nameParts(from name: String) -> (first: String, last: String) {
        let parts = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            .map(String.init)

        guard let first = parts.first else { return ("", "") }
        return (first, parts.count > 1 ? parts[1] : "")
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

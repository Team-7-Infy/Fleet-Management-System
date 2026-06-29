import Foundation
import Combine

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isPasswordVisible = false
    @Published private(set) var currentUser: User?

    let authService: AuthServiceProtocol

    init(authService: AuthServiceProtocol) {
        self.authService = authService
    }

    var isFormValid: Bool {
        email.contains("@") && email.contains(".") && password.count >= 6
    }

    func submit() async -> User? {
        guard isFormValid else {
            errorMessage = "Enter a valid email and password (6+ characters)."
            return nil
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            currentUser = try await authService.signIn(email: email, password: password)
            return currentUser
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}

import SwiftUI

struct FirstTimeSetupView: View {
    @Environment(\.colorScheme) private var colorScheme

    private let authService: AuthServiceProtocol
    private let user: User
    private let onComplete: (User) -> Void
    private let onLogout: () -> Void

    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isNewPasswordVisible = false
    @State private var isConfirmPasswordVisible = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    init(authService: AuthServiceProtocol, user: User, onComplete: @escaping (User) -> Void, onLogout: @escaping () -> Void = {}) {
        self.authService = authService
        self.user = user
        self.onComplete = onComplete
        self.onLogout = onLogout
    }

    private enum Field { case newPassword, confirmPassword }

    private enum PasswordStrength: String {
        case empty, veryWeak, weak, fair, strong, veryStrong

        var color: Color {
            switch self {
            case .empty:      return .clear
            case .veryWeak:   return Color(red: 0.85, green: 0.20, blue: 0.20)
            case .weak:       return Color(red: 0.90, green: 0.50, blue: 0.10)
            case .fair:       return Color(red: 0.95, green: 0.80, blue: 0.10)
            case .strong:     return Color(red: 0.20, green: 0.75, blue: 0.35)
            case .veryStrong: return Color(red: 0.10, green: 0.60, blue: 0.90)
            }
        }

        var progress: Double {
            switch self {
            case .empty:      return 0
            case .veryWeak:   return 0.15
            case .weak:       return 0.35
            case .fair:       return 0.55
            case .strong:     return 0.75
            case .veryStrong: return 1.0
            }
        }
    }

    private var strength: PasswordStrength {
        guard !newPassword.isEmpty else { return .empty }
        var score = 0
        if newPassword.count >= 8 { score += 1 }
        if newPassword.rangeOfCharacter(from: .uppercaseLetters) != nil { score += 1 }
        if newPassword.rangeOfCharacter(from: .lowercaseLetters) != nil { score += 1 }
        if newPassword.rangeOfCharacter(from: .decimalDigits) != nil { score += 1 }
        let special = CharacterSet.alphanumerics.union(.whitespaces).inverted
        if newPassword.rangeOfCharacter(from: special) != nil { score += 1 }
        switch score {
        case 0, 1: return .veryWeak
        case 2:    return .weak
        case 3:    return .fair
        case 4:    return .strong
        default:   return .veryStrong
        }
    }

    private var passwordsMatch: Bool {
        !newPassword.isEmpty && newPassword == confirmPassword
    }

    private var isValid: Bool {
        (strength == .strong || strength == .veryStrong) && passwordsMatch
    }

    var body: some View {
        ZStack {
            pageBackground.ignoresSafeArea()
            passwordSetup
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Sign Out") { onLogout() }
                    .foregroundStyle(.red)
            }
        }
        .onTapGesture { focusedField = nil }
    }

    // MARK: - Password Setup

    private var passwordSetup: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Welcome, \(user.fName)!")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("Set a secure password to activate your account.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 20)
            .padding(.horizontal, 24)

            passwordCard
                .padding(.top, 18)
                .padding(.horizontal, 24)

            if let errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text(errorMessage)
                }
                .font(.caption)
                .foregroundStyle(.red)
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }

            Spacer()

            Button(action: setPassword) {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView().tint(.white)
                    }
                    Text("Set Password & Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
            }
            .buttonStyle(FleetGlassButtonStyle())
            .buttonBorderShape(.capsule)
            .padding(.horizontal, 24)
            .disabled(!isValid || isLoading)

            Button {
                onLogout()
            } label: {
                Text("Cancel Activation")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
            .buttonStyle(.plain)
            .background(.regularMaterial, in: Capsule())
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private var passwordCard: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("New password")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                glassField {
                    Image(systemName: "lock")

                    Group {
                        if isNewPasswordVisible {
                            TextField("", text: $newPassword, prompt: Text("Required").foregroundStyle(placeholderColor))
                        } else {
                            SecureField("", text: $newPassword, prompt: Text("Required").foregroundStyle(placeholderColor))
                        }
                    }
                    .foregroundStyle(.primary)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .newPassword)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .confirmPassword }

                    Button {
                        isNewPasswordVisible.toggle()
                    } label: {
                        Image(systemName: isNewPasswordVisible ? "eye.slash" : "eye")
                            .contentTransition(.symbolEffect(.replace))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                }

                if !newPassword.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        GeometryReader { bar in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.primary.opacity(0.08))
                                    .frame(height: 4)
                                Capsule()
                                    .fill(strength.color)
                                    .frame(width: bar.size.width * strength.progress, height: 4)
                                    .animation(.spring(duration: 0.4), value: strength.progress)
                            }
                        }
                        .frame(height: 4)

                        Text(strength == .empty ? "" : strength.rawValue.uppercased())
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(strength.color)
                            .animation(.default, value: strength.rawValue)
                    }
                }
            }

            Divider().padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 10) {
                Text("Confirm password")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                glassField {
                    Image(systemName: "arrow.trianglehead.clockwise")

                    Group {
                        if isConfirmPasswordVisible {
                            TextField("", text: $confirmPassword, prompt: Text("Match password").foregroundStyle(placeholderColor))
                        } else {
                            SecureField("", text: $confirmPassword, prompt: Text("Match password").foregroundStyle(placeholderColor))
                        }
                    }
                    .foregroundStyle(.primary)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .confirmPassword)
                    .submitLabel(.done)
                    .onSubmit { focusedField = nil }

                    Button {
                        isConfirmPasswordVisible.toggle()
                    } label: {
                        Image(systemName: isConfirmPasswordVisible ? "eye.slash" : "eye")
                            .contentTransition(.symbolEffect(.replace))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(cardBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(.white.opacity(colorScheme == .dark ? 0.08 : 0.7), lineWidth: 0.8)
                }
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.34 : 0.1), radius: 24, x: 0, y: 14)
        }
    }

    private func setPassword() {
        guard isValid else { return }
        isLoading = true
        errorMessage = nil
        Task { @MainActor in
            do {
                try await authService.forceUpdatePassword(userId: user.id, password: newPassword)
                try await authService.markFirstTimeLoginComplete(userId: user.id)
                var activatedUser = user
                activatedUser.firstTimeLogin = false
                isLoading = false
                onComplete(activatedUser)
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Shared UI

    private func glassField<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            content()
        }
        .font(.body)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .frame(height: 56)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
    }

    private var placeholderColor: Color {
        colorScheme == .dark ? Color(white: 0.72) : Color(white: 0.38)
    }

    private var pageBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.035, green: 0.04, blue: 0.05)
            : Color(red: 0.975, green: 0.978, blue: 0.99)
    }

    private var cardBackground: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.075)
            : Color.white.opacity(0.82)
    }
}

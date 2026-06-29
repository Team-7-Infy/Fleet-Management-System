import SwiftUI

struct CreatePasswordView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    private let authService: AuthServiceProtocol

    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isNewPasswordVisible = false
    @State private var isConfirmPasswordVisible = false
    @State private var navigateToSuccess = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    init(authService: AuthServiceProtocol) {
        self.authService = authService
    }

    private enum Field { case newPassword, confirmPassword }

    private enum PasswordStrength: String {
        case empty      = ""
        case veryWeak   = "VERY WEAK"
        case weak       = "WEAK"
        case fair       = "FAIR"
        case strong     = "STRONG"
        case veryStrong = "VERY STRONG"

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
        if newPassword.count >= 8                                               { score += 1 }
        if newPassword.rangeOfCharacter(from: .uppercaseLetters) != nil         { score += 1 }
        if newPassword.rangeOfCharacter(from: .lowercaseLetters) != nil         { score += 1 }
        if newPassword.rangeOfCharacter(from: .decimalDigits) != nil            { score += 1 }
        let special = CharacterSet.alphanumerics.union(.whitespaces).inverted
        if newPassword.rangeOfCharacter(from: special) != nil                   { score += 1 }
        switch score {
        case 0, 1: return .veryWeak
        case 2:    return .weak
        case 3:    return .fair
        case 4:    return .strong
        default:   return .veryStrong
        }
    }

    private struct Requirement {
        let label: String
        let isMet: (String) -> Bool
    }

    private let requirements: [Requirement] = [
        .init(label: "Minimum 8 characters")  { $0.count >= 8 },
        .init(label: "One uppercase letter")   { $0.rangeOfCharacter(from: .uppercaseLetters) != nil },
        .init(label: "One lowercase letter")   { $0.rangeOfCharacter(from: .lowercaseLetters) != nil },
        .init(label: "One number")             { $0.rangeOfCharacter(from: .decimalDigits) != nil },
        .init(label: "One special character")  {
            $0.rangeOfCharacter(from: CharacterSet.alphanumerics.union(.whitespaces).inverted) != nil
        },
    ]

    private var passwordsMatch: Bool {
        !newPassword.isEmpty && newPassword == confirmPassword
    }

    private var isValid: Bool {
        strength == .veryStrong && passwordsMatch
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Create Your Password")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("Set a secure password to complete account activation.")
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

            VStack(spacing: 12) {
                Button(action: setPassword) {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView().tint(.white)
                        }
                        Text("Set Password")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                    }
                }
                .buttonStyle(FleetGlassButtonStyle())
                .buttonBorderShape(.capsule)
                .disabled(!isValid || isLoading)

                Button {
                    dismiss()
                } label: {
                    Text("Cancel Activation")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .buttonStyle(.plain)
                .background(.regularMaterial, in: Capsule())
            }
            .padding(.top, 6)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(pageBackground.ignoresSafeArea())
        .onTapGesture { focusedField = nil }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToSuccess) {
            PasswordResetSuccessView(authService: authService)
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
                            TextField(
                                "",
                                text: $newPassword,
                                prompt: Text(verbatim: "Required")
                                    .foregroundStyle(placeholderColor)
                            )
                        } else {
                            SecureField(
                                "",
                                text: $newPassword,
                                prompt: Text(verbatim: "Required")
                                    .foregroundStyle(placeholderColor)
                            )
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
                    .accessibilityLabel(isNewPasswordVisible ? "Hide password" : "Show password")
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

                        Text(strength.rawValue)
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
                            TextField(
                                "",
                                text: $confirmPassword,
                                prompt: Text(verbatim: "Match password")
                                    .foregroundStyle(placeholderColor)
                            )
                        } else {
                            SecureField(
                                "",
                                text: $confirmPassword,
                                prompt: Text(verbatim: "Match password")
                                    .foregroundStyle(placeholderColor)
                            )
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
                    .accessibilityLabel(isConfirmPasswordVisible ? "Hide password" : "Show password")
                }
            }

            Divider().padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(requirements, id: \.label) { req in
                    HStack(spacing: 10) {
                        Image(systemName: req.isMet(newPassword) ? "checkmark.circle.fill" : "checkmark.circle")
                            .foregroundStyle(req.isMet(newPassword) ? Color.green : placeholderColor)
                            .animation(.spring(duration: 0.3), value: req.isMet(newPassword))

                        Text(req.label)
                            .font(.subheadline)
                            .foregroundStyle(req.isMet(newPassword) ? Color.primary : placeholderColor)
                            .animation(.default, value: req.isMet(newPassword))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(cardBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(.white.opacity(colorScheme == .dark ? 0.08 : 0.7), lineWidth: 0.8)
                }
                .shadow(
                    color: .black.opacity(colorScheme == .dark ? 0.34 : 0.1),
                    radius: 24, x: 0, y: 14
                )
        }
    }

    private func setPassword() {
        guard isValid else { return }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await authService.updateUserPassword(password: newPassword)
                isLoading = false
                navigateToSuccess = true
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func glassField<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
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
        colorScheme == .dark
            ? Color(white: 0.72)
            : Color(white: 0.38)
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

import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    private let authService: AuthServiceProtocol

    @State private var forgotEmail = ""
    @State private var navigateToVerify = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var isEmailFocused: Bool

    init(authService: AuthServiceProtocol) {
        self.authService = authService
    }

    private var isEmailValid: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        return forgotEmail.range(of: emailRegex, options: .regularExpression) != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            iconSection
                .padding(.top, 20)
                .padding(.horizontal, 24)

            headingSection
                .padding(.top, 20)
                .padding(.horizontal, 24)

            emailCard
                .padding(.top, 24)

            if let errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text(errorMessage)
                }
                .font(.caption)
                .foregroundStyle(FleetPalette.danger)
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }

            Spacer()

            actionButtons
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .background(pageBackground.ignoresSafeArea())
        .onTapGesture { isEmailFocused = false }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToVerify) {
            VerifyEmailView(authService: authService, forgotEmail: forgotEmail)
        }
    }

    private var iconSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            FleetPalette.accent,
                            FleetPalette.secondary
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 82, height: 82)
                .shadow(color: Color.black.opacity(0.15),
                        radius: 4, x: 0, y: 2)

            Image(systemName: "envelope.badge")
                .font(.system(size: 36))
                .foregroundStyle(.white)
        }
    }

    private var headingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Forgot Password?")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text("Enter the email address associated with your account.\n\nWe'll send you a verification code to reset your password.")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var emailCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Email")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)

            glassField {
                Image(systemName: "envelope")

                TextField(
                    "",
                    text: $forgotEmail,
                    prompt: Text("user@example.com")
                        .foregroundStyle(placeholderColor)
                )
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isEmailFocused)
                .submitLabel(.go)
                .onSubmit(sendCode)
            }
            .padding(.horizontal, 20)

            if !forgotEmail.isEmpty && !isEmailValid {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption)
                    Text("Enter a valid email address")
                        .font(.caption)
                }
                .foregroundStyle(FleetPalette.danger)
                .padding(.horizontal, 20)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: sendCode) {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView().tint(.white)
                    }
                    Text("Send Verification Code")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
            }
            .buttonStyle(FleetGlassButtonStyle())
            .buttonBorderShape(.capsule)
            .disabled(!isEmailValid || isLoading)

            Button {
                dismiss()
            } label: {
                Text("Back to Sign In")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
            .buttonStyle(.plain)
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(.regularMaterial, in: Capsule())
        }
    }

    private func sendCode() {
        guard isEmailValid else { return }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await authService.sendRecoveryOTP(email: forgotEmail)
                isLoading = false
                navigateToVerify = true
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

    private var textColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var pageBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.035, green: 0.04, blue: 0.05)
            : FleetPalette.background
    }
}

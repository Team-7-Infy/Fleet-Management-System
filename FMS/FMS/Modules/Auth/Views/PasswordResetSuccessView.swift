import SwiftUI

struct PasswordResetSuccessView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismissToRoot) private var dismissToRoot

    private let authService: AuthServiceProtocol
    @State private var isSigningOut = false

    init(authService: AuthServiceProtocol) {
        self.authService = authService
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)

                Text("Password Updated")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("Your password has been updated successfully.\n\nYou can now sign in using your new password.")
                    .multilineTextAlignment(.center)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.top, 60)

            Spacer()

            Button {
                signOutAndDismiss()
            } label: {
                HStack(spacing: 8) {
                    if isSigningOut {
                        ProgressView().tint(.white)
                    }
                    Text("Continue to Login")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
            }
            .buttonStyle(FleetGlassButtonStyle())
            .buttonBorderShape(.capsule)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .disabled(isSigningOut)
        }
        .background(pageBackground.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(isSigningOut)
    }

    private func signOutAndDismiss() {
        isSigningOut = true
        Task {
            do {
                try await authService.signOut()
            } catch {}
            isSigningOut = false
            dismissToRoot()
        }
    }

    private var pageBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.035, green: 0.04, blue: 0.05)
            : Color(red: 0.975, green: 0.978, blue: 0.99)
    }
}

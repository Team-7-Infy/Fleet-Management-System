import SwiftUI

struct VerifyEmailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    private let authService: AuthServiceProtocol
    private let forgotEmail: String

    @State private var otpCode = ""
    @State private var navigateToCreatePassword = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var isOTPFocused: Bool

    private let otpLength = 6

    init(authService: AuthServiceProtocol, forgotEmail: String = "") {
        self.authService = authService
        self.forgotEmail = forgotEmail
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
                    .shadow(color: FleetPalette.accent.opacity(0.45),
                            radius: 14, x: 0, y: 6)
                    .shadow(color: Color.black.opacity(0.15),
                            radius: 4, x: 0, y: 2)

                Image(systemName: "shield.checkered")
                    .font(.system(size: 40))
                    .foregroundStyle(.white)
            }
            .padding(.top, 20)
            .padding(.horizontal, 24)

            VStack(alignment: .leading, spacing: 8) {
                Text("Verify Email")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("We've sent a 6-digit code to your registered email address.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 20)
            .padding(.horizontal, 24)

            otpBoxes
                .padding(.top, 24)
                .padding(.horizontal, 24)

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

            Button("Didn't receive the code?") {
                resendCode()
            }
            .font(.subheadline)
            .foregroundStyle(FleetPalette.accent)
            .underline()
            .padding(.top, 16)
            .padding(.horizontal, 24)

            Spacer()

            Button(action: verifyCode) {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView().tint(.white)
                    }
                    Text("Verify Code")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
            }
            .buttonStyle(FleetGlassButtonStyle())
            .buttonBorderShape(.capsule)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .disabled(otpCode.count != otpLength || isLoading)
        }
        .background(pageBackground.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onTapGesture { isOTPFocused = false }
        .navigationDestination(isPresented: $navigateToCreatePassword) {
            CreatePasswordView(authService: authService)
        }
    }

    private var otpBoxes: some View {
        ZStack {
            TextField("", text: $otpCode)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isOTPFocused)
                .frame(width: 1, height: 1)
                .opacity(0.001)
                .onChange(of: otpCode) { _, newValue in
                    let filtered = newValue.filter { $0.isNumber }
                    otpCode = String(filtered.prefix(otpLength))
                }

            HStack(spacing: 10) {
                ForEach(0..<otpLength, id: \.self) { index in
                    otpBox(at: index)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { isOTPFocused = true }
    }

    private func otpBox(at index: Int) -> some View {
        let chars = Array(otpCode)
        let char: String = index < chars.count ? String(chars[index]) : ""
        let isCurrent = isOTPFocused && otpCode.count == index

        return ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(boxBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            isCurrent ? FleetPalette.accent : borderColor,
                            lineWidth: isCurrent ? 2 : 1
                        )
                }
                .shadow(
                    color: .black.opacity(colorScheme == .dark ? 0.25 : 0.06),
                    radius: 6, x: 0, y: 3
                )

            if char.isEmpty && isCurrent {
                RoundedRectangle(cornerRadius: 2)
                    .fill(FleetPalette.accent)
                    .frame(width: 2, height: 24)
                    .opacity(0.85)
            } else {
                Text(char)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.primary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .animation(.spring(duration: 0.2), value: isCurrent)
    }

    private func verifyCode() {
        guard otpCode.count == otpLength else { return }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await authService.verifyOTP(email: forgotEmail, token: otpCode)
                isLoading = false
                navigateToCreatePassword = true
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func resendCode() {
        Task {
            do {
                try await authService.sendRecoveryOTP(email: forgotEmail)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private var pageBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.035, green: 0.04, blue: 0.05)
            : FleetPalette.background
    }

    private var boxBackground: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.white.opacity(0.90)
    }

    private var borderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.15)
            : Color.black.opacity(0.12)
    }
}

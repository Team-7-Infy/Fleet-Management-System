import SwiftUI

extension EnvironmentValues {
    @Entry var dismissToRoot: () -> Void = {}
}

struct LoginView: View {
    @StateObject private var viewModel: LoginViewModel
    var onLogin: (User?) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var focusedField: Field?
    @State private var navigateToForgotPassword = false

    private enum Field {
        case email
        case password
    }

    init(authService: AuthServiceProtocol, onLogin: @escaping (User?) -> Void) {
        _viewModel = StateObject(wrappedValue: LoginViewModel(authService: authService))
        self.onLogin = onLogin
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                hero(height: heroHeight(for: geometry.size.width))

                VStack(spacing: 28) {
                    welcomeText
                    signInCard
                    Spacer(minLength: 28)
                    // Terms and Privacy links are hidden until those pages exist.
                }
                .padding(.horizontal, 24)
                .padding(.bottom, max(20, geometry.safeAreaInsets.bottom + 8))
                .frame(maxHeight: .infinity)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(pageBackground.ignoresSafeArea())
        }
        .ignoresSafeArea(edges: .top)
        .onTapGesture { focusedField = nil }
        .navigationDestination(isPresented: $navigateToForgotPassword) {
            ForgotPasswordView(authService: viewModel.authService)
        }
        .environment(\.dismissToRoot) {
            navigateToForgotPassword = false
        }
    }

    private func hero(height: CGFloat) -> some View {
        Image("Fleet-illustration")
            .resizable()
            .scaledToFill()
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .clipped()
            .overlay {
                if colorScheme == .dark {
                    Color.black.opacity(0.32)
                }
            }
            .overlay(alignment: .bottom) {
                LinearGradient(
                    stops: [
                        .init(color: pageBackground.opacity(0), location: 0),
                        .init(color: pageBackground.opacity(0.2), location: 0.22),
                        .init(color: pageBackground.opacity(0.88), location: 0.76),
                        .init(color: pageBackground, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: min(190, height * 0.52))
                .offset(y: 1)
            }
            .accessibilityHidden(true)
    }

    private var welcomeText: some View {
        VStack(spacing: 6) {
            Text("Welcome")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text("Manage your fleet with confidence")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(.top, -40)
    }

    private var signInCard: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Email")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                glassField {
                    Image(systemName: "envelope")

                    TextField(
                        "",
                        text: $viewModel.email,
                        prompt: Text(verbatim: "Email")
                            .foregroundStyle(placeholderColor)
                    )
                    .foregroundStyle(textColor)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Password")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Forgot Password?") {
                        navigateToForgotPassword = true
                    }
                        .font(.subheadline.weight(.semibold))
                        .buttonStyle(.plain)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                glassField {
                    Image(systemName: "lock")

                    Group {
                        if viewModel.isPasswordVisible {
                            TextField(
                                "",
                                text: $viewModel.password,
                                prompt: Text("Password")
                                    .foregroundStyle(placeholderColor)
                            )
                        } else {
                            SecureField(
                                "",
                                text: $viewModel.password,
                                prompt: Text("Password")
                                    .foregroundStyle(placeholderColor)
                            )
                        }
                    }
                    .foregroundStyle(.primary)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit(submit)

                    Button {
                        viewModel.isPasswordVisible.toggle()
                    } label: {
                        Image(systemName: viewModel.isPasswordVisible ? "eye.slash" : "eye")
                            .contentTransition(.symbolEffect(.replace))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(viewModel.isPasswordVisible ? "Hide password" : "Show password")
                }
            }

            FeedbackView(success: nil, error: viewModel.errorMessage)
                .padding(.top, -8)

            Button(action: submit) {
                HStack(spacing: 8) {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    }
                    Text("Sign In")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
            }
            .buttonStyle(FleetGlassButtonStyle())
            .buttonBorderShape(.capsule)
            .disabled(viewModel.isLoading || !viewModel.isFormValid)
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
                    radius: 24,
                    x: 0,
                    y: 14
                )
        }
        .frame(maxWidth: 540)
        .frame(maxWidth: .infinity)
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

    private func submit() {
        focusedField = nil
        Task {
            let user = await viewModel.submit()
            onLogin(user)
        }
    }

    private func heroHeight(for availableWidth: CGFloat) -> CGFloat {
        min(max(availableWidth * 0.78, 245), 340)
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
            : Color(red: 0.975, green: 0.978, blue: 0.99)
    }

    private var cardBackground: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.075)
            : Color.white.opacity(0.82)
    }
}

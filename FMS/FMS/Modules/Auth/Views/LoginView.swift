import SwiftUI
import AVFoundation
import Combine

extension EnvironmentValues {
    @Entry var dismissToRoot: () -> Void = {}
}

struct LoginView: View {
    @StateObject private var viewModel: LoginViewModel
    var onLogin: (User?) -> Void
    private let preloadedAssets: LoginAssets?

    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var focusedField: Field?
    @State private var navigateToForgotPassword = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var activeKeyboardHeight: CGFloat = 0

    private enum Field {
        case email
        case password
    }

    init(authService: AuthServiceProtocol, preloadedAssets: LoginAssets? = nil, onLogin: @escaping (User?) -> Void) {
        _viewModel = StateObject(wrappedValue: LoginViewModel(authService: authService))
        self.preloadedAssets = preloadedAssets
        self.onLogin = onLogin
    }

    // Configurable parameters for video tweaking
    private let videoScale: CGFloat = 1.0
    private let videoOffsetX: CGFloat = 0.0
    private let videoOffsetY: CGFloat = 0.0

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // Background color base
                Color(hex: 0x041125)
                    .ignoresSafeArea()

                // Background Video starting from top, touching left/right, keeping aspect ratio constant
                LoopingVideoPlayerView(preloadedAssets: preloadedAssets)
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width * 16/9)
                    .scaleEffect(videoScale)
                    .offset(x: videoOffsetX, y: videoOffsetY)
                    .ignoresSafeArea(edges: .top)

                // Top gradient overlay — solid black (25%) top → transparent bottom (stays static)
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.25),
                        Color.black.opacity(0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: UIScreen.main.bounds.height * 0.20)
                .ignoresSafeArea(edges: .top)

                // Top left logo "Fleet-Logo-Text" — shifted down and scaled up
                VStack(alignment: .leading) {
                    HStack {
                        Image("Fleet-Logo-Text")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 45) // Double the size (was 28)
                            .padding(.leading, 24)
                            .padding(.top, geometry.safeAreaInsets.top + 65) // Shifted down by 100
                        Spacer()
                    }
                    Spacer()
                }

                // White login card edge-to-edge at the bottom with rounded top corners
                VStack(spacing: 0) {
                    Spacer()

                    VStack(alignment: .leading, spacing: 20) {
                        Text("Login")
                            .font(.custom("ClashGrotesk-Medium", size: 32))
                            .foregroundStyle(FleetPalette.textPrimary)
                            .padding(.top, 32)
                            .padding(.horizontal, 24)

                        signInCard
                            .padding(.horizontal, 24)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 24 + (activeKeyboardHeight > 0 ? activeKeyboardHeight : geometry.safeAreaInsets.bottom))
                    .background(
                        UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20)
                            .fill(FleetPalette.surface)
                            .ignoresSafeArea(edges: .bottom)
                    )
                }
                .ignoresSafeArea(.all, edges: .bottom)

                // Toast overlay at the top
                if showToast {
                    VStack {
                        LoginErrorToastView(message: toastMessage)
                            .padding(.top, geometry.safeAreaInsets.top + 12)
                            .padding(.horizontal, 24)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        Spacer()
                    }
                    .zIndex(100)
                }
            }
            .onChange(of: geometry.safeAreaInsets.bottom) { _, newValue in
                if newValue > 100 {
                    // Lock onto the maximum keyboard height seen to prevent switching jitters
                    if activeKeyboardHeight == 0 || newValue > activeKeyboardHeight {
                        withAnimation(.easeOut(duration: 0.25)) {
                            activeKeyboardHeight = newValue
                        }
                    }
                } else {
                    // Reset when keyboard is fully dismissed or hardware keyboard is toggled
                    withAnimation(.easeOut(duration: 0.25)) {
                        activeKeyboardHeight = 0
                    }
                }
            }
        }
        .ignoresSafeArea(.container, edges: .all)
        .onTapGesture { focusedField = nil }
        .navigationDestination(isPresented: $navigateToForgotPassword) {
            ForgotPasswordView(authService: viewModel.authService)
        }
        .environment(\.dismissToRoot) {
            navigateToForgotPassword = false
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            if let msg = newValue, !msg.isEmpty {
                showToastMessage(msg)
            }
        }
    }

    private func showToastMessage(_ message: String) {
        toastMessage = message
        withAnimation(.spring(duration: 0.4)) {
            showToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation(.spring(duration: 0.4)) {
                showToast = false
            }
        }
    }

    private var signInCard: some View {
        VStack(spacing: 20) {
            // Email Field
            glassField(isFocused: focusedField == .email) {
                Image(systemName: "envelope")
                    .foregroundStyle(focusedField == .email ? Color("FleetAccentBlue") : .gray)

                TextField(
                    "",
                    text: $viewModel.email,
                    prompt: Text(verbatim: "username@fms.com")
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

            // Password Field & Forgot Password
            VStack(alignment: .leading, spacing: 12) {
                glassField(isFocused: focusedField == .password) {
                    Image(systemName: "lock")
                        .padding(.leading, 4)
                        .foregroundStyle(focusedField == .password ? Color("FleetAccentBlue") : .gray)

                    Group {
                        if viewModel.isPasswordVisible {
                            TextField(
                                "",
                                text: $viewModel.password,
                                prompt: Text("••••••••")
                                    .font(.system(size: 22))
                                    .foregroundStyle(placeholderColor)
                            )
                        } else {
                            SecureField(
                                "",
                                text: $viewModel.password,
                                prompt: Text("••••••••")
                                    .font(.system(size: 22))
                                    .foregroundStyle(placeholderColor)
                            )
                        }
                    }
                    .foregroundStyle(textColor)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .padding(.leading, 2)
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
                            .foregroundStyle(.gray)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(viewModel.isPasswordVisible ? "Hide password" : "Show password")
                }

                HStack {
                    Spacer()

                    Button("Forgot Password?") {
                        navigateToForgotPassword = true
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color("FleetAccentBlue"))
                    .buttonStyle(.plain)
                }
            }

            // Sign In Button
            Button(action: submit) {
                HStack(spacing: 8) {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    }
                    Text("Sign In")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
            }
            .buttonStyle(.plain)
            .tint(Color("FleetAccentBlue"))
            .glassEffect(.regular.tint(Color("FleetAccentBlue").opacity(0.9)), in: .capsule)
            .padding(.top, 2)
        }
        .frame(maxWidth: 540)
        .frame(maxWidth: .infinity)
    }

    private func glassField<Content: View>(
        isFocused: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            content()
        }
        .font(.body)
        .foregroundStyle(FleetPalette.textPrimary)
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(isFocused ? Color("FleetAccentBlue") : Color.clear, lineWidth: 2)
        )
        .glassEffect(.clear, in: .rect(cornerRadius: 18))
    }

    private func submit() {
        focusedField = nil
        Task {
            let user = await viewModel.submit()
            onLogin(user)
        }
    }

    private var placeholderColor: Color {
        Color.gray.opacity(0.5)
    }

    private var textColor: Color {
        FleetPalette.textPrimary
    }

    private var pageBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.035, green: 0.04, blue: 0.05)
            : FleetPalette.background
    }

    private var cardBackground: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.075)
            : Color.white.opacity(0.82)
    }
}

// MARK: - Login Error Toast View
struct LoginErrorToastView: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.white)
                .font(.system(size: 16, weight: .semibold))

            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.8, green: 0.15, blue: 0.15).opacity(0.92))
                .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
        }
    }
}

// MARK: - Background Looping Video Player
struct LoopingVideoPlayerView: View {
    /// Pass the pre-built player from SplashView to avoid reloading the video.
    let preloadedAssets: LoginAssets?

    init(preloadedAssets: LoginAssets? = nil) {
        self.preloadedAssets = preloadedAssets
    }

    @State private var player: AVQueuePlayer?
    @State private var playerLooper: AVPlayerLooper?

    var body: some View {
        VideoPlayerContainerView(player: player)
            .onAppear {
                if let assets = preloadedAssets, player == nil {
                    // Use the player that was pre-built during splash
                    player       = assets.videoPlayer
                    playerLooper = assets.videoLooper
                    assets.videoPlayer.play()
                } else {
                    setupPlayer()
                }
            }
            .onDisappear {
                player?.pause()
            }
    }

    private func setupPlayer() {
        guard player == nil else {
            player?.play()
            return
        }

        // Load video from Assets.xcassets dataset
        guard let asset = NSDataAsset(name: "BG-Video") else {
            print("Failed to find BG-Video asset")
            return
        }

        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent("BG-Video.mp4")

        do {
            try asset.data.write(to: fileURL, options: .atomic)

            let playerItem = AVPlayerItem(url: fileURL)
            let queuePlayer = AVQueuePlayer(playerItem: playerItem)
            let looper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)

            self.player = queuePlayer
            self.playerLooper = looper

            queuePlayer.isMuted = true
            queuePlayer.play()
        } catch {
            print("Error writing temp video file: \(error)")
        }
    }
}

struct VideoPlayerContainerView: UIViewRepresentable {
    let player: AVQueuePlayer?

    func makeUIView(context: Context) -> UIView {
        let view = PlayerUIView()
        view.player = player
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let playerView = uiView as? PlayerUIView {
            playerView.player = player
        }
    }
}

class PlayerUIView: UIView {
    private let playerLayer = AVPlayerLayer()

    var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        playerLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}

// MARK: - Safe Area Layout offset is now used.

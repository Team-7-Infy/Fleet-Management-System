import SwiftUI
import AVFoundation

// Preloaded login-screen assets — built during the splash and handed to LoginView
struct LoginAssets {
    let videoPlayer: AVQueuePlayer
    let videoLooper: AVPlayerLooper
}

struct SplashView: View {
    let authService: AuthServiceProtocol
    /// Called when splash is done.
    /// - Parameters:
    ///   - user: The authenticated user (nil → show login)
    ///   - assets: Pre-loaded video player + looper (nil → video failed to load)
    let onComplete: (User?, LoginAssets?) -> Void

    // Minimum time the splash is always shown (seconds)
    private let minimumDuration: Double = 2.0

    var body: some View {
        ZStack {
            // Full-bleed brand background
            Color("FleetAccentBlue")
                .ignoresSafeArea()

            // Centred logo — static
            Image("Fleet-Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 160, height: 160)
        }
        .task {
            // ── Run all three in parallel ────────────────────────────────
            async let authResult   = fetchSession()
            async let assetsResult = preloadLoginAssets()
            async let timerDone    = minimumTimer()

            // Wait for all three — splash stays until every one finishes
            let (user, assets, _) = await (authResult, assetsResult, timerDone)

            onComplete(user, assets)
        }
    }

    // MARK: - Helpers

    /// Resolves the current auth session (nil = not logged in).
    private func fetchSession() async -> User? {
        try? await authService.currentSession()
    }

    /// Blocks for the minimum splash duration.
    private func minimumTimer() async {
        try? await Task.sleep(for: .seconds(minimumDuration))
    }

    /// Writes BG-Video to a temp file and builds the AVQueuePlayer.
    /// Returns nil if the asset is missing or the write fails.
    private func preloadLoginAssets() async -> LoginAssets? {
        return await Task.detached(priority: .userInitiated) {
            guard let dataAsset = NSDataAsset(name: "BG-Video") else {
                print("SplashView: BG-Video asset not found")
                return nil
            }

            let fileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("BG-Video.mp4")

            do {
                try dataAsset.data.write(to: fileURL, options: .atomic)
            } catch {
                print("SplashView: Failed to write BG-Video — \(error)")
                return nil
            }

            let item       = AVPlayerItem(url: fileURL)
            let player     = AVQueuePlayer(playerItem: item)
            let looper     = AVPlayerLooper(player: player, templateItem: item)
            player.isMuted = true
            // Don't play yet — LoginView will call play() on appear
            return LoginAssets(videoPlayer: player, videoLooper: looper)
        }.value
    }
}

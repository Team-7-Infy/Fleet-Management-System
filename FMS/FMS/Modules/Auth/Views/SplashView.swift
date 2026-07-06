import SwiftUI

struct SplashView: View {
    let authService: AuthServiceProtocol
    let onComplete: (User?) -> Void

    @State private var opacity = 0.0

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image("SplashLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            Text("Fleet Manager")
                .font(.largeTitle.bold())
                .foregroundStyle(FleetPalette.textPrimary)

            Text("Loading...")
                .font(.subheadline)
                .foregroundStyle(FleetPalette.textSecondary)

            ProgressView()
                .tint(FleetPalette.accent)
                .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FleetPalette.background)
        .opacity(opacity)
        .task {
            withAnimation(.easeIn(duration: 0.4)) {
                opacity = 1
            }
            try? await Task.sleep(for: .seconds(0.8))
            if let user = try? await authService.currentSession() {
                onComplete(user)
            } else {
                onComplete(nil)
            }
        }
    }
}

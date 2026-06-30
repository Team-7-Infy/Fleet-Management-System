import SwiftUI

struct SplashView: View {
    let authService: AuthServiceProtocol
    let onComplete: (User?) -> Void

    @State private var opacity = 0.0

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "car.2.fill")
                .font(.system(size: 72))
                .foregroundStyle(FleetPalette.primary)

            Text("Fleet Manager")
                .font(.largeTitle.bold())
                .foregroundStyle(FleetPalette.textPrimary)

            Text("Loading...")
                .font(.subheadline)
                .foregroundStyle(FleetPalette.textSecondary)

            ProgressView()
                .tint(FleetPalette.primary)
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

import SwiftUI

struct FleetGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .background {
                FleetPalette.accent
                    .opacity(configuration.isPressed ? 0.7 : 1)
            }
            .clipShape(Capsule())
    }
}

struct GlassProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: [
                        FleetPalette.accent,
                        FleetPalette.secondary
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(configuration.isPressed ? 0.7 : 1),
                in: Capsule()
            )
    }
}

struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(FleetPalette.accent)
            .background(
                Capsule()
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.06 : 0.04))
                    .overlay(
                        Capsule()
                            .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                    )
            )
    }
}

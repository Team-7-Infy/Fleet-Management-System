import SwiftUI

struct FleetGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .background {
                FleetPalette.primary
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
                        Color(red: 0.15, green: 0.45, blue: 0.98),
                        Color(red: 0.08, green: 0.30, blue: 0.85)
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
            .foregroundStyle(.blue)
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


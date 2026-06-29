import SwiftUI

struct PrimaryButton: View {
    let title: String
    var systemImage: String?
    var action: () -> Void

    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            action()
        }) {
            Label(title, systemImage: systemImage ?? "arrow.right")
                .font(AppTypography.headline)
                .frame(maxWidth: .infinity, minHeight: 50)
                .contentShape(Rectangle())
        }
        .buttonStyle(PrimaryButtonStyle())
        .accessibilityLabel(title)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(AppColor.brand)
            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous))
            .shadow(color: AppColor.brand.opacity(configuration.isPressed ? 0.0 : 0.3), radius: 8, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    PrimaryButton(title: "Continue", systemImage: "arrow.right") { }
        .padding()
}

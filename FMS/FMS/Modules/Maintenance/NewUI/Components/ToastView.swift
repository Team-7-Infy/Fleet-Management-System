import SwiftUI

struct ToastView: View {
    let message: String
    var systemImage = AppIcon.checkmark

    var body: some View {
        Label(message, systemImage: systemImage)
            .font(AppTypography.callout.weight(.semibold))
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.medium)
            .background(.regularMaterial, in: Capsule())
            .accessibilityLabel(message)
    }
}

#Preview {
    ToastView(message: "Saved")
        .padding()
}

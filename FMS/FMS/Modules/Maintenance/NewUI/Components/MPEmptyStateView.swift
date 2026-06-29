import SwiftUI

struct MPEmptyStateView: View {
    let title: String
    let message: String
    var systemImage: String = "tray"

    var body: some View {
        VStack(spacing: AppSpacing.large) {
            Image(systemName: systemImage)
                .font(.system(size: 48, weight: .regular))
                .foregroundStyle(AppColor.brand.opacity(0.6))
            VStack(spacing: AppSpacing.xSmall) {
                Text(title)
                    .font(AppTypography.headline)
                Text(message)
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(AppSpacing.xLarge)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    MPEmptyStateView(title: "No Jobs", message: "Assigned work orders will appear here.")
}

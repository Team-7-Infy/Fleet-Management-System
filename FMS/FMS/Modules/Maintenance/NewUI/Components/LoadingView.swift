import SwiftUI

struct LoadingView: View {
    var title = "Loading"

    var body: some View {
        VStack(spacing: AppSpacing.medium) {
            ProgressView()
            Text(title)
                .font(AppTypography.callout)
                .foregroundStyle(AppColor.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    LoadingView()
}

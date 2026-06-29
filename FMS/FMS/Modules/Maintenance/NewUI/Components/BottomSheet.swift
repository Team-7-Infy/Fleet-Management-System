import SwiftUI

struct BottomSheet<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            Capsule()
                .fill(AppColor.separator)
                .frame(width: 42, height: 5)
                .frame(maxWidth: .infinity)
            Text(title)
                .font(AppTypography.title)
            content
        }
        .padding(AppSpacing.large)
        .background(AppColor.surface)
        .clipShape(.rect(cornerRadius: AppCornerRadius.large, style: .continuous))
    }
}

#Preview {
    BottomSheet(title: "Options") {
        Text("Placeholder content")
    }
}

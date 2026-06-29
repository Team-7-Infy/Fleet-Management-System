import SwiftUI

struct PhotoAttachmentView: View {
    var title = "Attachment"

    var body: some View {
        VStack(spacing: AppSpacing.small) {
            Image(systemName: AppIcon.photo)
                .font(.title2)
                .foregroundStyle(AppColor.brand)
            Text(title)
                .font(AppTypography.caption)
                .foregroundStyle(AppColor.textSecondary)
        }
        .frame(width: 84, height: 84)
        .background(AppColor.secondaryBackground, in: RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    PhotoAttachmentView()
        .padding()
}

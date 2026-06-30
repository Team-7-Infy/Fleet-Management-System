import SwiftUI

struct SummaryCard: View {
    let title: String
    let value: String
    let systemImage: String
    var tint: Color = AppColor.brand

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .font(.title3.weight(.bold))
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(value)
                .font(AppTypography.title)
            Text(title)
                .font(AppTypography.footnote)
                .foregroundStyle(AppColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardStyle()
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    SummaryCard(title: "Assigned", value: "14", systemImage: "tray.full.fill")
        .padding()
}

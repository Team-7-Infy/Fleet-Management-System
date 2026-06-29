import SwiftUI

struct DetailRow: View {
    let title: String
    let value: String
    var systemImage: String?

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.medium) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.callout)
                    .foregroundStyle(AppColor.brand)
                    .frame(width: 22)
                    .accessibilityHidden(true)
            }

            Text(title)
                .font(AppTypography.callout)
                .foregroundStyle(AppColor.textSecondary)

            Spacer(minLength: AppSpacing.large)

            Text(value.nonEmptyAccessibilityValue)
                .font(AppTypography.callout.weight(.semibold))
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    DetailRow(title: "Status", value: "Under Maintenance", systemImage: "info.circle")
        .padding()
}

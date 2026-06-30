import SwiftUI

struct InspectionChecklistItem: View {
    @Binding var item: MPInspectionItem

    var body: some View {
        Button {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                item.isComplete.toggle()
            }
        } label: {
            HStack(spacing: AppSpacing.medium) {
                Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isComplete ? AppColor.brand : AppColor.textSecondary.opacity(0.5))
                    .font(.title2)
                    .scaleEffect(item.isComplete ? 1.05 : 1.0)

            Text(item.title)
                .font(AppTypography.body)
                    .foregroundStyle(AppColor.textPrimary)
                Spacer()
            }
            .padding(.vertical, AppSpacing.xSmall)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityValue(item.isComplete ? "Complete" : "Incomplete")
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    @Previewable @State var item = PreviewData.inspectionItems[0]
    InspectionChecklistItem(item: $item)
        .padding()
}

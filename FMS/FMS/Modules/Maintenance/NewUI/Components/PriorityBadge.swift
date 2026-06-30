import SwiftUI

struct PriorityBadge: View {
    let priority: Priority

    var body: some View {
        Text(priority.title)
            .font(AppTypography.caption.weight(.semibold))
            .padding(.horizontal, AppSpacing.small)
            .padding(.vertical, AppSpacing.xSmall)
            .foregroundStyle(priority.color)
            .background(priority.color.opacity(0.12), in: Capsule())
            .accessibilityLabel(priority.title)
    }
}

#Preview {
    HStack {
        ForEach(Priority.allCases) { priority in
            PriorityBadge(priority: priority)
        }
    }
    .padding()
}

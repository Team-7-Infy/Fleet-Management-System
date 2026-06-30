import SwiftUI

struct ProgressIndicatorView: View {
    let progress: Double
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            HStack {
                Text(label)
                    .font(AppTypography.footnote)
                Spacer()
                Text(progress, format: .percent.precision(.fractionLength(0)))
                    .font(AppTypography.footnote.weight(.semibold))
            }
            ProgressView(value: progress)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ProgressIndicatorView(progress: 0.38, label: "Inspection")
        .padding()
}

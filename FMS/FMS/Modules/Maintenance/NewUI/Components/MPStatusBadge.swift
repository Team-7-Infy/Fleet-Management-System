import SwiftUI

struct MPStatusBadge: View {
    let status: JobStatus

    var body: some View {
        Text(status.title.uppercased())
            .font(AppTypography.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(status.color)
            .background(status.color.opacity(0.15), in: Capsule())
            .accessibilityLabel("Status \(status.title)")
    }
}

#Preview {
    HStack {
        ForEach(JobStatus.allCases) { status in
            MPStatusBadge(status: status)
        }
    }
    .padding()
}

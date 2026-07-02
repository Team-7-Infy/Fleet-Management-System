import SwiftUI

struct MPStatusBadge: View {
    let status: JobStatus

    var body: some View {
        StatusDot(text: status.title, color: status.color)
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

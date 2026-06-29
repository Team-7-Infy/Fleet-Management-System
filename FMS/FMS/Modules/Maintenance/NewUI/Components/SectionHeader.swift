import SwiftUI

struct MPSectionHeader: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .font(AppTypography.headline)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(AppTypography.callout)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    MPSectionHeader(title: "Upcoming Maintenance", actionTitle: "View All") { }
        .padding()
}

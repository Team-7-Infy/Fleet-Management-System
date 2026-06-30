import SwiftUI

struct SecondaryButton: View {
    let title: String
    var systemImage: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage ?? "chevron.right")
                .font(AppTypography.headline)
                .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .accessibilityLabel(title)
    }
}

#Preview {
    SecondaryButton(title: "View Details") { }
        .padding()
}

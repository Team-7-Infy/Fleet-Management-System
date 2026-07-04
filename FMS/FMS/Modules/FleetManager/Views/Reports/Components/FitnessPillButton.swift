import SwiftUI

struct FitnessPillButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(FleetPalette.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(FleetPalette.tertiary.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
    }
}

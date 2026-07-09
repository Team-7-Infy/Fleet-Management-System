import SwiftUI

struct NotificationBadge: View {
    let unreadCount: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onTap()
        }) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell")
                    .font(.system(size: 20))
                    .foregroundStyle(FleetPalette.accent)

                if unreadCount > 0 {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                        Text("\(unreadCount)")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 16, height: 16)
                    .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Notifications")
    }
}

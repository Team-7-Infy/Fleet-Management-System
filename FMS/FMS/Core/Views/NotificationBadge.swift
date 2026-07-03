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
                    .foregroundColor(.primary)
                    .frame(width: 38, height: 38)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(Circle())

                if unreadCount > 0 {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                        Text("\(unreadCount)")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .frame(width: 16, height: 16)
                    .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

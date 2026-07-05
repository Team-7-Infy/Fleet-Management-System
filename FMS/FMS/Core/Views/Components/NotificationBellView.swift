import SwiftUI

struct NotificationBellView: View {
    @ObservedObject var service: NotificationService
    
    var body: some View {
        NavigationLink(destination: NotificationScreen(service: service)) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 20))
                    .foregroundColor(AppColor.textPrimary)
                
                if service.unreadCount > 0 {
                    let displayCount = service.unreadCount > 99 ? "99+" : "\(service.unreadCount)"
                    Text(displayCount)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(Color.red)
                        .clipShape(Capsule())
                        .offset(x: 8, y: -6)
                }
            }
            .padding(8)
        }
        .accessibilityLabel("Notifications")
        .accessibilityValue(service.unreadCount > 0 ? "\(service.unreadCount) unread notifications" : "No unread notifications")
    }
}

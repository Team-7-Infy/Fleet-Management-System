import SwiftUI

struct NotificationBannerView: View {
    let notification: AppNotification
    let onTap: () -> Void
    let onDismiss: () -> Void

    @State private var dragOffset: CGFloat = 0

    private var systemImageName: String {
        switch notification.type {
        case "user_created": return "person.badge.plus.fill"
        case "trip_assignment": return "map.fill"
        case "geofence_exit", "route_deviation": return "exclamationmark.triangle.fill"
        case "vehicle_assigned": return "truck.box.fill"
        case "trip_started": return "play.circle.fill"
        case "trip_completed": return "checkmark.circle.fill"
        case "trip_delay": return "clock.badge.exclamationmark.fill"
        case "driver_message": return "message.fill"
        case "work_order_assigned": return "wrench.adjustable.fill"
        case "work_order_request": return "wrench.fill"
        default: return "bell.fill"
        }
    }

    private var iconColor: Color {
        switch notification.type {
        case "geofence_exit", "route_deviation", "trip_delay": return .red
        case "user_created": return .green
        case "trip_assignment", "vehicle_assigned", "work_order_assigned": return .blue
        case "trip_started", "trip_completed": return .green
        default: return .orange
        }
    }

    var body: some View {
        VStack {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 38, height: 38)
                    Image(systemName: systemImageName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(notification.title.cleaningUUIDs)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Text(notification.message.cleaningUUIDs)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .padding(16)
            .background(.thinMaterial)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .offset(y: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        if gesture.translation.height < 0 {
                            dragOffset = gesture.translation.height
                        }
                    }
                    .onEnded { gesture in
                        if gesture.translation.height < -30 {
                            onDismiss()
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
            .onTapGesture {
                onTap()
            }
            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

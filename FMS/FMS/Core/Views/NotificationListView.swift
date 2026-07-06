import SwiftUI

struct NotificationListView: View {
    @ObservedObject var viewModel: NotificationViewModel

    private var groupedNotifications: [(String, [AppNotification])] {
        let calendar = Calendar.current
        let today = viewModel.notifications.filter { calendar.isDateInToday($0.createdAt) }
        let yesterday = viewModel.notifications.filter { calendar.isDateInYesterday($0.createdAt) }
        let earlier = viewModel.notifications.filter { 
            !calendar.isDateInToday($0.createdAt) && !calendar.isDateInYesterday($0.createdAt) 
        }

        var groups: [(String, [AppNotification])] = []
        if !today.isEmpty { groups.append(("Today", today)) }
        if !yesterday.isEmpty { groups.append(("Yesterday", yesterday)) }
        if !earlier.isEmpty { groups.append(("Earlier", earlier)) }
        return groups
    }

    var body: some View {
        Group {
            if viewModel.notifications.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(groupedNotifications, id: \.0) { groupName, items in
                        Section(header: Text(groupName).font(.footnote).bold().foregroundStyle(.secondary)) {
                            ForEach(items) { item in
                                NotificationRow(notification: item) {
                                    Task {
                                        await viewModel.markAsRead(item)
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    if !item.isRead {
                                        Button {
                                            Task {
                                                await viewModel.markAsRead(item)
                                            }
                                        } label: {
                                            Label("Mark Read", systemImage: "envelope.open")
                                        }
                                        .tint(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !viewModel.notifications.isEmpty && viewModel.unreadCount > 0 {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Mark All Read") {
                        Task {
                            await viewModel.markAllAsRead()
                        }
                    }
                    .font(.subheadline)
                }
            }
        }
        .task {
            await viewModel.loadNotifications()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.slash")
                .font(.system(size: 60))
                .foregroundStyle(.secondary.opacity(0.6))
            Text("No Notifications")
                .font(.title3)
                .bold()
                .foregroundStyle(.primary)
            Text("You're all caught up! New alerts regarding your fleet and trips will show up here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding()
    }
}

struct NotificationRow: View {
    let notification: AppNotification
    let onMarkRead: () -> Void

    private var systemImageName: String {
        switch notification.type {
        case "user_created": return "person.badge.plus.fill"
        case "trip_assignment": return "map.fill"
        case "geofence_exit": return "exclamationmark.triangle.fill"
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
        case "geofence_exit", "trip_delay": return .red
        case "user_created": return .green
        case "trip_assignment", "vehicle_assigned", "work_order_assigned": return .blue
        case "trip_started", "trip_completed": return .green
        default: return .orange
        }
    }

    var body: some View {
        Button {
            if !notification.isRead {
                onMarkRead()
            }
        } label: {
            HStack(spacing: 12) {
                if !notification.isRead {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                } else {
                    Spacer()
                        .frame(width: 8)
                }

                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: systemImageName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(iconColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(notification.title.cleaningUUIDs)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text(notification.message.cleaningUUIDs)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    Text(formattedTime(notification.createdAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }

                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            formatter.dateStyle = .none
            formatter.timeStyle = .short
        } else {
            formatter.dateStyle = .short
            formatter.timeStyle = .short
        }
        return formatter.string(from: date)
    }
}

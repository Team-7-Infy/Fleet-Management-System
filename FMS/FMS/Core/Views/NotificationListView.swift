import SwiftUI

struct NotificationListView: View {
    @ObservedObject var viewModel: NotificationViewModel
    @Environment(\.dismiss) private var dismiss

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
        NavigationStack {
            Group {
                if viewModel.notifications.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(groupedNotifications, id: \.0) { groupName, items in
                            Section(header: Text(groupName).font(.footnote).fontWeight(.bold).foregroundColor(.secondary)) {
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
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }

                if !viewModel.notifications.isEmpty && viewModel.unreadCount > 0 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Mark All Read") {
                            Task {
                                await viewModel.markAllAsRead()
                            }
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                }
            }
            .task {
                await viewModel.loadNotifications()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.6))
            Text("No Notifications")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            Text("You're all caught up! New alerts regarding your fleet and trips will show up here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
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
        case "trip_assignment", "vehicle_assigned", "work_order_assigned": return .blue
        case "trip_started", "trip_completed": return .green
        default: return .orange
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Unread indicator dot
            if !notification.isRead {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
            } else {
                Spacer()
                    .frame(width: 8)
            }

            // Category Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: systemImageName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(notification.title.cleaningUUIDs)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text(notification.message.cleaningUUIDs)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                Text(formattedTime(notification.createdAt))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.8))
                    .padding(.top, 2)
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if !notification.isRead {
                onMarkRead()
            }
        }
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

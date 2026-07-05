import SwiftUI

struct NotificationScreen: View {
    @ObservedObject var service: NotificationService
    
    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            
            if service.isLoading && service.notifications.isEmpty {
                ProgressView()
                    .scaleEffect(1.5)
            } else if service.notifications.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 48))
                        .foregroundColor(AppColor.textSecondary)
                    Text("No notifications")
                        .font(.headline)
                        .foregroundColor(AppColor.textPrimary)
                }
            } else {
                List {
                    let urgentNotifs = service.notifications.filter { $0.type == "work_order_assigned_urgent" }
                    let normalNotifs = service.notifications.filter { $0.type != "work_order_assigned_urgent" }
                    
                    if !urgentNotifs.isEmpty {
                        Section {
                            ForEach(urgentNotifs) { notification in
                                NotificationRow(notification: notification)
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                    .onTapGesture {
                                        Task {
                                            await service.markAsRead(notification)
                                        }
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            service.hideNotification(notification)
                                        } label: {
                                            Label("Clear", systemImage: "trash")
                                        }
                                    }
                            }
                        } header: {
                            Text("Urgent Tasks")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.red)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                        }
                    }
                    
                    if !normalNotifs.isEmpty {
                        Section {
                            ForEach(normalNotifs) { notification in
                                NotificationRow(notification: notification)
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                    .onTapGesture {
                                        Task {
                                            await service.markAsRead(notification)
                                        }
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            service.hideNotification(notification)
                                        } label: {
                                            Label("Clear", systemImage: "trash")
                                        }
                                    }
                            }
                        } header: {
                            Text("Normal Tasks")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.gray)
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                        }
                    }
                }
                .listStyle(.plain)
                .background(AppColor.background)
                .scrollContentBackground(.hidden)
                .refreshable {
                    await service.fetchNotifications()
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if service.notifications.isEmpty {
                Task {
                    await service.fetchNotifications()
                    await service.markAllAsRead()
                }
            } else {
                Task {
                    await service.markAllAsRead()
                }
            }
        }
    }
}

struct NotificationRow: View {
    let notification: AppNotification
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // Icon in circle with border
            ZStack {
                Circle()
                    .fill(notification.type.contains("urgent") ? Color.red.opacity(0.1) : AppColor.brand.opacity(0.1))
                    .frame(width: 48, height: 48)
                
                Image(systemName: notification.sfSymbolName)
                    .font(.system(size: 20))
                    .foregroundColor(notification.type.contains("urgent") ? .red : AppColor.brand)
            }
            
            // Middle text content
            VStack(alignment: .leading, spacing: 6) {
                Text(notification.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(AppColor.textPrimary)
                    .lineLimit(2)
                
                Text(notification.message)
                    .font(.system(size: 13))
                    .foregroundColor(AppColor.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Bottom blue text simulating the "in stock" format
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                    Text(formatExactDate(notification.createdAt))
                        .font(AppTypography.caption)
                }
                .foregroundColor(AppColor.brand)
            }
            
            Spacer()
            
            Image(systemName: "chevron.backward.2")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.gray.opacity(0.6))
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func formatExactDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd • hh:mm a"
        return formatter.string(from: date)
    }
}

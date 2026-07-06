import SwiftUI

struct NotificationListView: View {
    @ObservedObject var viewModel: NotificationViewModel
    @State private var selectedFilter: NotificationFilter = .all
    @State private var selectedNotification: AppNotification? = nil
    var services: AppServices?

    enum NotificationFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case unread = "Unread"
        
        var id: String { rawValue }
    }

    private var filteredNotifications: [AppNotification] {
        switch selectedFilter {
        case .all:
            return viewModel.notifications
        case .unread:
            return viewModel.notifications.filter { !$0.isRead }
        }
    }

    private var groupedNotifications: [(String, [AppNotification])] {
        let calendar = Calendar.current
        let src = filteredNotifications
        let today = src.filter { calendar.isDateInToday($0.createdAt) }
        let yesterday = src.filter { calendar.isDateInYesterday($0.createdAt) }
        let earlier = src.filter { 
            !calendar.isDateInToday($0.createdAt) && !calendar.isDateInYesterday($0.createdAt) 
        }

        var groups: [(String, [AppNotification])] = []
        if !today.isEmpty { groups.append(("Today", today)) }
        if !yesterday.isEmpty { groups.append(("Yesterday", yesterday)) }
        if !earlier.isEmpty { groups.append(("Earlier", earlier)) }
        return groups
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Filter", selection: $selectedFilter) {
                ForEach(NotificationFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Group {
                if filteredNotifications.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(groupedNotifications, id: \.0) { groupName, items in
                            Section(header: Text(groupName).font(.footnote).bold().foregroundStyle(.secondary)) {
                                ForEach(items) { item in
                                    NotificationRow(notification: item, onMarkRead: {
                                        Task {
                                            await viewModel.markAsRead(item)
                                        }
                                    }, onTap: {
                                        selectedNotification = item
                                    })
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
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            Task {
                                                await viewModel.deleteNotification(item)
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !viewModel.notifications.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if viewModel.unreadCount > 0 {
                            Button {
                                Task { await viewModel.markAllAsRead() }
                            } label: {
                                Label("Mark All Read", systemImage: "envelope.open")
                            }
                        }
                        Button(role: .destructive) {
                            Task { await viewModel.clearAllNotifications() }
                        } label: {
                            Label("Clear All", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .navigationDestination(item: $selectedNotification) { notification in
            NotificationDetailView(notification: notification, services: services)
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
        .frame(maxHeight: .infinity)
    }
}

struct NotificationRow: View {
    let notification: AppNotification
    let onMarkRead: () -> Void
    let onTap: () -> Void

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
            onTap()
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

struct NotificationDetailView: View {
    let notification: AppNotification
    var services: AppServices?
    @Environment(\.dismiss) var dismiss

    @State private var tripDetails: (vehiclePlate: String, driverName: String, route: String, status: String)?

    var body: some View {
        VStack(spacing: 24) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: systemImageName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(iconColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(notification.title.cleaningUUIDs)
                        .font(.headline)
                        .fontWeight(.bold)
                    Text(formattedTime(notification.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.top, 24)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("DESCRIPTION")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                
                ScrollView {
                    Text(notification.message.cleaningUUIDs)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(nil)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
                .frame(maxHeight: 180)
            }

            if let details = tripDetails {
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    Text("TRIP DETAILS")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    TripDetailRow(label: "Vehicle", value: details.vehiclePlate)
                    TripDetailRow(label: "Driver", value: details.driverName)
                    TripDetailRow(label: "Route", value: details.route)
                    TripDetailRow(label: "Status", value: details.status)
                }
            }
            
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Text("Dismiss")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .cornerRadius(14)
            }
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 24)
        .task {
            await loadTripDetails()
        }
    }

    @MainActor
    private func loadTripDetails() async {
        guard let services, let tripId = notification.referenceId else { return }
        do {
            let trip = try await services.tripService.fetchTrip(id: tripId)
            let vehicle = try? await services.vehicleService.fetchVehicle(id: trip.vehicleId ?? UUID())
            let driverName: String
            if let driverId = trip.driverId {
                let users = (try? await services.userManagementService.fetchUsers()) ?? []
                if let user = users.first(where: { $0.id == driverId }) {
                    driverName = "\(user.fName) \(user.lName)".trimmingCharacters(in: .whitespaces)
                } else {
                    driverName = "Unknown"
                }
            } else {
                driverName = "Unassigned"
            }
            tripDetails = (
                vehiclePlate: vehicle?.licencePlate ?? "Unknown",
                driverName: driverName,
                route: "\(trip.startLocation) → \(trip.endLocation)",
                status: trip.status.rawValue.capitalized
            )
        } catch {
            print("Failed to fetch trip details: \(error)")
        }
    }

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

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct TripDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

import SwiftUI
import Combine

struct MPDashboardView: View {
    @StateObject private var notificationViewModel: NotificationViewModel
    @StateObject private var viewModel: MPDashboardViewModel
    @ObservedObject private var navigation: TabNavigationState

    @Environment(\.scenePhase) private var scenePhase
    @State private var isShowingProfile = false
    @State private var isShowingNotifications = false
    @State private var workOrderToStart: WorkOrder.ID?
    @State private var isTodayExpanded = false
    private let dependencies: AppDependencyContainer
    private let onLogout: () -> Void

    init(dependencies: AppDependencyContainer, navigation: TabNavigationState, onLogout: @escaping () -> Void = {}, notificationService: NotificationServiceProtocol) {
        _viewModel = StateObject(wrappedValue: MPDashboardViewModel(dependencies: dependencies))
        _notificationViewModel = StateObject(wrappedValue: NotificationViewModel(
            notificationService: notificationService,
            recipientId: nil,
            role: .maintenance
        ))
        self.dependencies = dependencies
        self.navigation = navigation
        self.onLogout = onLogout
    }

    @State private var searchText = ""
    @State private var selectedTab = "Today"
    let tabs = ["Today", "Pending", "Upcoming", "History"]
    
    private func tabTitle(for key: String) -> String {
        let count: Int
        switch key {
        case "Today": count = viewModel.todayWorkOrders.count
        case "Pending": count = viewModel.pendingWorkOrders.count
        case "Upcoming": count = viewModel.upcomingWorkOrders.count
        case "History": count = viewModel.completedWorkOrders.count
        default: count = 0
        }
        return "\(key) (\(count))"
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            
            searchAndTabs
            
            ScrollView {
                VStack(spacing: 16) {
                    if viewModel.state.isLoading {
                        ProgressView()
                            .padding(.top, 40)
                    } else if filteredWorkOrders.isEmpty {
                        MPEmptyStateView(title: "No Tasks", message: "There are no tasks matching your current filter.", systemImage: "tray")
                            .padding(.top, 40)
                    } else {
                        let urgentOrders = filteredWorkOrders.filter { $0.workOrder.isUrgent == true }
                        let normalOrders = filteredWorkOrders.filter { $0.workOrder.isUrgent != true }
                        
                        if !urgentOrders.isEmpty {
                            HStack {
                                Text("Urgent Tasks")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(AppColor.destructive)
                                Spacer()
                            }
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                            
                            ForEach(urgentOrders, id: \.workOrder.id) { dashboardOrder in
                                Button {
                                    if dashboardOrder.workOrder.status == .completed || dashboardOrder.workOrder.status == .fake {
                                        navigation.push(.pastWorkOrderDetails(workOrderID: dashboardOrder.workOrder.id))
                                    } else {
                                        let vId = dashboardOrder.vehicle?.id.uuidString ?? dashboardOrder.workOrder.vehicleID
                                        navigation.push(.vehicleWorkOrderDetails(vehicleID: vId, workOrderID: dashboardOrder.workOrder.id))
                                    }
                                } label: {
                                    whiteThemeCard(for: dashboardOrder)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        if !normalOrders.isEmpty {
                            HStack {
                                Text("Normal Tasks")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.gray)
                                Spacer()
                            }
                            .padding(.top, 16)
                            .padding(.bottom, 4)
                            
                            ForEach(normalOrders, id: \.workOrder.id) { dashboardOrder in
                                Button {
                                    if dashboardOrder.workOrder.status == .completed || dashboardOrder.workOrder.status == .fake {
                                        navigation.push(.pastWorkOrderDetails(workOrderID: dashboardOrder.workOrder.id))
                                    } else {
                                        let vId = dashboardOrder.vehicle?.id.uuidString ?? dashboardOrder.workOrder.vehicleID
                                        navigation.push(.vehicleWorkOrderDetails(vehicleID: vId, workOrderID: dashboardOrder.workOrder.id))
                                    }
                                } label: {
                                    whiteThemeCard(for: dashboardOrder)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .padding(.bottom, 60)
            }
            .refreshable {
                await viewModel.load()
            }
        }
        .background(Color(hex: 0xF4F5F9).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $isShowingProfile) {
            MPProfileView(dependencies: dependencies, onLogout: onLogout)
        }
        .navigationDestination(isPresented: $isShowingNotifications) {
            NotificationListView(viewModel: notificationViewModel)
        }
        .task {
            await viewModel.load()
            if let userId = viewModel.user?.id {
                notificationViewModel.setRecipientId(userId)
            }
            await notificationViewModel.loadNotifications()
            notificationViewModel.subscribeToRealtime()
        }
        .onAppear {
            Task {
                await viewModel.load()
            }
        }
        .refreshable {
            await viewModel.load(isRefresh: true)
        }
        .onReceive(Timer.publish(every: 20, on: .main, in: .common).autoconnect()) { _ in
            Task {
                await viewModel.load(isRefresh: true)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await viewModel.load(isRefresh: true)
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Home")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.black)
            
            Spacer()
            
            HStack(spacing: 16) {
                NotificationBadge(unreadCount: notificationViewModel.unreadCount) {
                    isShowingNotifications = true
                }
                Button {
                    isShowingProfile = true
                } label: {
                    if let imageData = viewModel.user?.profileImageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                    } else if let avatarURL = viewModel.user?.avatarurl.flatMap(URL.init(string:)) {
                        CachedAsyncImage(url: avatarURL) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 36, height: 36)
                                .clipShape(Circle())
                        } placeholder: {
                            Circle()
                                .fill(LinearGradient(colors: [AppColor.inProgress, AppColor.inProgress.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 36, height: 36)
                        }
                    } else {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [AppColor.inProgress, AppColor.inProgress.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 36, height: 36)
                            
                            if let name = viewModel.user?.name {
                                Text(initials(for: name))
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.white)
                            } else {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.white)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white)
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 16)
    }
    
    private var searchAndTabs: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.gray)
                
                TextField("Search tasks", text: $searchText)
                    .font(.system(size: 16, weight: .medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(hex: 0xE8EAED))
            .clipShape(Capsule())
            
            HStack(spacing: 0) {
                ForEach(tabs, id: \.self) { tab in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedTab = tab
                        }
                    } label: {
                        Text(tabTitle(for: tab))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(selectedTab == tab ? Color.black : Color.gray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(selectedTab == tab ? Color.white : Color.clear)
                            .clipShape(Capsule())
                            .shadow(color: selectedTab == tab ? Color.black.opacity(0.04) : .clear, radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(Color(hex: 0xE8EAED))
            .clipShape(Capsule())
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private var filteredWorkOrders: [DashboardWorkOrder] {
        var baseList: [DashboardWorkOrder] = []
        
        switch selectedTab {
        case "Today":
            baseList = viewModel.todayWorkOrders
        case "Pending":
            baseList = viewModel.pendingWorkOrders
        case "Upcoming":
            baseList = viewModel.upcomingWorkOrders
        case "History":
            baseList = viewModel.completedWorkOrders
        default:
            baseList = []
        }
        
        if !searchText.isEmpty {
            baseList = baseList.filter {
                $0.workOrder.title.localizedCaseInsensitiveContains(searchText) ||
                ($0.vehicle?.licencePlate.localizedCaseInsensitiveContains(searchText) ?? false) ||
                ($0.vehicle?.make.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        return baseList
    }

    private func whiteThemeCard(for dashboardOrder: DashboardWorkOrder) -> some View {
        let workOrder = dashboardOrder.workOrder
        let vehicle = dashboardOrder.vehicle
        let vehicleDisplay = vehicle != nil ? "\(vehicle!.make) \(vehicle!.model)" : "Unknown Vehicle"
        let plateDisplay = vehicle != nil ? vehicle!.formattedLicencePlate : "No Plate"
        
        let statusColor: Color
        let statusText: String
        let statusBgColor: Color
        
        if workOrder.status == .completed {
            statusColor = AppColor.success
            statusBgColor = AppColor.success.opacity(0.1)
            statusText = "COMPLETED"
        } else if workOrder.status == .fake {
            statusColor = AppColor.destructive
            statusBgColor = AppColor.destructive.opacity(0.1)
            statusText = "FAKE"
        } else if workOrder.status == .inProgress {
            statusColor = AppColor.warning
            statusBgColor = AppColor.warning.opacity(0.1)
            statusText = "IN PROGRESS"
        } else {
            statusColor = AppColor.inProgress
            statusBgColor = AppColor.inProgress.opacity(0.1)
            statusText = "PENDING"
        }
        
        let dateString: String
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMM"
        
        if workOrder.status == .completed || workOrder.status == .fake {
            if let completedDateStr = workOrder.completedAt {
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                var cDate = isoFormatter.date(from: completedDateStr)
                if cDate == nil {
                    let fallback = DateFormatter()
                    fallback.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    cDate = fallback.date(from: completedDateStr)
                }
                if let validDate = cDate {
                    dateString = "Completed on: \(dateFormatter.string(from: validDate))"
                } else {
                    dateString = "Completed on: Unknown"
                }
            } else {
                dateString = "Completed on: Unknown"
            }
        } else {
            dateString = "Scheduled on: \(dateFormatter.string(from: workOrder.dueDate))"
        }
        
        return HStack(alignment: .center, spacing: 16) {
            VehicleAssetImage(vehicle: vehicle, width: 46, height: 36, cornerRadius: 9)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text(plateDisplay)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.black)
                    
                    Spacer()
                    
                    Text(statusText)
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(statusBgColor)
                        .foregroundStyle(statusColor)
                        .clipShape(Capsule())
                }
                
                Text(workOrder.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.black)
                    .lineLimit(1)
                
                Text(dateString)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.gray)
                
                HStack(spacing: 4) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text(vehicleDisplay)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundStyle(AppColor.brand)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColor.inProgress.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        guard !parts.isEmpty else { return "" }
        if parts.count == 1 {
            return String(parts[0].prefix(2)).uppercased()
        }
        return (String(parts[0].prefix(1)) + String(parts[1].prefix(1))).uppercased()
    }
}

#Preview {
    let mock = PreviewNotificationService()
    NavigationStack {
        MPDashboardView(dependencies: .mock(), navigation: TabNavigationState(), notificationService: mock)
    }
} 

private actor PreviewNotificationService: NotificationServiceProtocol {
    func fetchNotifications(for recipientId: UUID?, driverId: UUID?) async throws -> [AppNotification] { [] }
    func createNotification(_ notification: AppNotification) async throws -> AppNotification { notification }
    func markAsRead(id: UUID) async throws {}
    func markAllAsRead(for recipientId: UUID?, driverId: UUID?) async throws {}
    func deleteNotification(id: UUID) async throws {}
    func clearAllNotifications(for userId: UUID) async throws {}
    func subscribeToRealtime(for recipientId: UUID?, driverId: UUID?) -> AsyncStream<AppNotification> {
        AsyncStream { $0.finish() }
    }
    func subscribeToTripsRealtime(forDriverId driverId: UUID) -> AsyncStream<Trip> {
        AsyncStream { $0.finish() }
    }
}

import Combine
import SwiftUI

struct MPDashboardView: View {
    @StateObject private var viewModel: MPDashboardViewModel
    @ObservedObject private var navigation: TabNavigationState

    @Environment(\.scenePhase) private var scenePhase
    @State private var isShowingProfile = false
    @State private var workOrderToStart: WorkOrder.ID?
    @State private var isTodayExpanded = false
    private let dependencies: AppDependencyContainer
    private let onLogout: () -> Void

    init(dependencies: AppDependencyContainer, navigation: TabNavigationState, onLogout: @escaping () -> Void = {}) {
        _viewModel = StateObject(wrappedValue: MPDashboardViewModel(dependencies: dependencies))
        self.dependencies = dependencies
        self.navigation = navigation
        self.onLogout = onLogout
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                header
                
                if viewModel.state.isLoading {
                    LoadingView(title: "Loading dashboard")
                } else {
                    todaySection
                    upcomingSection
                    unfinishedTasksSection
                    historySection
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, AppSpacing.large)
            .padding(.bottom, 60)
        }
        .background(AppColor.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isShowingProfile) {
            MPProfileView(dependencies: dependencies, onLogout: onLogout)
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
        .alert(
            "Start Work Order",
            isPresented: Binding(
                get: { workOrderToStart != nil },
                set: { if !$0 { workOrderToStart = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) {
                workOrderToStart = nil
            }
            Button("Start") {
                if let id = workOrderToStart {
                    navigation.push(.completeWorkOrder(workOrderID: id))
                }
                workOrderToStart = nil
            }
        } message: {
            Text("Do you want to start this work order?")
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12:
            return "Good Morning"
        case 12..<17:
            return "Good Afternoon"
        default:
            return "Good Evening"
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColor.textSecondary)
                Text(viewModel.user?.name ?? "John Carter")
                    .font(AppTypography.largeTitle)
                    .minimumScaleFactor(0.75)
                    .accessibilityAddTraits(.isHeader)
                
            }

            Spacer()

            HStack(spacing: AppSpacing.medium) {
                Button {
                    isShowingProfile = true
                } label: {
                    if let imageData = viewModel.user?.profileImageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 48, height: 48)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: FleetIcon.account)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 48, height: 48)
                            .foregroundStyle(AppColor.brand)
                            .background(Circle().fill(Color.white))
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var todaySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text("Today")
                .font(AppTypography.title)
                .foregroundStyle(AppColor.textPrimary)
            
            if viewModel.todayWorkOrders.isEmpty {
                MPEmptyStateView(title: "No Tasks Today", message: "You're all caught up for today.", systemImage: FleetIcon.calendar)
            } else {
                VStack(spacing: 0) {
                    let itemsToShow = isTodayExpanded ? viewModel.todayWorkOrders : Array(viewModel.todayWorkOrders.prefix(5))
                    ForEach(Array(itemsToShow.enumerated()), id: \.element.id) { index, item in
                        Button {
                            // push to summary
                        } label: {
                            workOrderRow(for: item, isLast: index == itemsToShow.count - 1 && (isTodayExpanded || viewModel.todayWorkOrders.count <= 5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .shadow(color: AppColor.textPrimary.opacity(0.06), radius: 8, x: 0, y: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                        )
                )
                
                if !isTodayExpanded && viewModel.todayWorkOrders.count > 5 {
                    let extraCount = viewModel.todayWorkOrders.count - 5
                    Button(action: {
                        withAnimation {
                            isTodayExpanded = true
                        }
                    }) {
                        Text("+\(extraCount) more")
                            .font(AppTypography.callout.weight(.medium))
                            .foregroundStyle(AppColor.brand)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                }
            }
        }
        .padding(.bottom, AppSpacing.medium)
    }
    
    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            if viewModel.upcomingWorkOrdersFiltered.count > 5 {
                sectionHeaderWithAction(title: "Upcoming", actionTitle: "View All") {
                    navigation.push(.allUpcomingWorkOrders)
                }
            } else {
                Text("Upcoming")
                    .font(AppTypography.title)
                    .foregroundStyle(AppColor.textPrimary)
            }
            
            if viewModel.upcomingWorkOrdersFiltered.isEmpty {
                MPEmptyStateView(title: "No Upcoming Tasks", message: "You don't have any upcoming tasks scheduled.", systemImage: FleetIcon.calendar)
            } else {
                VStack(spacing: 0) {
                    let itemsToShow = Array(viewModel.upcomingWorkOrdersFiltered.prefix(5))
                    ForEach(Array(itemsToShow.enumerated()), id: \.element.id) { index, item in
                        Button {
                            // push to summary
                        } label: {
                            workOrderRow(for: item, isLast: index == itemsToShow.count - 1, showDate: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .shadow(color: AppColor.textPrimary.opacity(0.06), radius: 8, x: 0, y: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                        )
                )
            }
        }
        .padding(.bottom, AppSpacing.medium)
    }

    private var unfinishedTasksSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            if viewModel.backlogWorkOrders.count > 5 {
                sectionHeaderWithAction(title: "Unfinished Tasks", actionTitle: "View All") {
                    navigation.push(.allUnfinishedWorkOrders)
                }
            } else {
                Text("Unfinished Tasks")
                    .font(AppTypography.title)
                    .foregroundStyle(AppColor.textPrimary)
            }
            
            if viewModel.backlogWorkOrders.isEmpty {
                MPEmptyStateView(title: "No Unfinished Tasks", message: "You don't have any past tasks pending.", systemImage: "tray")
            } else {
                VStack(spacing: 0) {
                    let itemsToShow = Array(viewModel.backlogWorkOrders.prefix(5))
                    ForEach(Array(itemsToShow.enumerated()), id: \.element.id) { index, item in
                        Button {
                            // push to summary
                        } label: {
                            workOrderRow(for: item, isLast: index == itemsToShow.count - 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .shadow(color: AppColor.textPrimary.opacity(0.06), radius: 8, x: 0, y: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                        )
                )
            }
        }
        .padding(.bottom, AppSpacing.medium)
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            if viewModel.completedWorkOrders.count > 3 {
                sectionHeaderWithAction(title: "History", actionTitle: "View All") {
                    navigation.push(.allHistoryWorkOrders)
                }
            } else {
                Text("History")
                    .font(AppTypography.title)
                    .foregroundStyle(AppColor.textPrimary)
            }
            
            if viewModel.completedWorkOrders.isEmpty {
                MPEmptyStateView(title: "No History", message: "You don't have any completed tasks.", systemImage: "clock")
            } else {
                VStack(spacing: 0) {
                    let itemsToShow = Array(viewModel.completedWorkOrders.prefix(3))
                    ForEach(Array(itemsToShow.enumerated()), id: \.element.id) { index, item in
                        Button {
                            navigation.push(.pastWorkOrderDetails(workOrderID: item.workOrder.id))
                        } label: {
                            historyWorkOrderRow(for: item, isLast: index == itemsToShow.count - 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .shadow(color: AppColor.textPrimary.opacity(0.06), radius: 8, x: 0, y: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                        )
                )
            }
        }
    }

    private func workOrderRow(for dashboardOrder: DashboardWorkOrder, isLast: Bool, showDate: Bool = false) -> some View {
        let workOrder = dashboardOrder.workOrder
        let vehicle = dashboardOrder.vehicle
        let vehicleDisplay = vehicle != nil ? "\(vehicle!.make) \(vehicle!.model)" : "Unknown"
        
        return VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "car.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(AppColor.brand)
                    .frame(width: 36, height: 36)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(vehicleDisplay)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColor.textPrimary)
                    
                    HStack(spacing: 8) {
                        Text(workOrder.title)
                            .font(.system(size: 12))
                            .foregroundStyle(AppColor.textSecondary)
                            .lineLimit(1)
                        
                        if workOrder.isUrgent == true {
                            Text("Urgent")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.1))
                                .foregroundStyle(Color.red)
                                .cornerRadius(4)
                        }
                    }
                    
                    if showDate {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                            Text(workOrder.dueDate.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(Color.gray)
                        .padding(.top, 2)
                    }
                }
                
                Spacer()
                
                Button {
                    workOrderToStart = workOrder.id
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.15))
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: "play.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.green.opacity(0.7))
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            
            if !isLast {
                Divider()
                    .padding(.leading, 44 + 12 + 16)
                    .padding(.trailing, 16)
            }
        }
    }
    
    private func historyWorkOrderRow(for dashboardOrder: DashboardWorkOrder, isLast: Bool) -> some View {
        let workOrder = dashboardOrder.workOrder
        let vehicle = dashboardOrder.vehicle
        let vehicleDisplay = vehicle != nil ? "\(vehicle!.make) \(vehicle!.model)" : "Unknown"
        
        return VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "car.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(AppColor.brand)
                    .frame(width: 36, height: 36)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(vehicleDisplay)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColor.textPrimary)
                    
                    HStack(spacing: 8) {
                        Text(workOrder.title)
                            .font(.system(size: 12))
                            .foregroundStyle(AppColor.textSecondary)
                            .lineLimit(1)
                        
                        if workOrder.isUrgent == true {
                            Text("Urgent")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.1))
                                .foregroundStyle(Color.red)
                                .cornerRadius(4)
                        }
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: FleetIcon.checkmark)
                            .font(.system(size: 10))
                            .foregroundStyle(Color.green)
                        Text("Completed")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.green)
                        
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.gray)
                        
                        Image(systemName: "stopwatch")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.gray)
                        Text(workOrder.formattedElapsedTime)
                            .font(.system(size: 10))
                            .foregroundStyle(Color.gray)
                        
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.gray)
                        
                        Image(systemName: "calendar")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.gray)
                        Text(workOrder.completedDateFormatted)
                            .font(.system(size: 10))
                            .foregroundStyle(Color.gray)
                    }
                }
                
                Spacer()
                
                Image(systemName: FleetIcon.chevronRight)
                    .foregroundStyle(Color.gray)
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            
            if !isLast {
                Divider()
                    .padding(.leading, 44 + 12 + 16)
                    .padding(.trailing, 16)
            }
        }
    }

    private func sectionHeaderWithAction(title: String, actionTitle: String, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(AppTypography.title)
                .foregroundStyle(AppColor.textPrimary)
            Spacer()
            Button(action: action) {
                HStack(spacing: 2) {
                    Text(actionTitle)
                    Image(systemName: FleetIcon.chevronRight)
                        .font(AppTypography.callout.weight(.semibold))
                }
                .font(AppTypography.callout.weight(.medium))
                .foregroundStyle(AppColor.brand)
            }
        }
    }
}

#Preview {
    NavigationStack {
        MPDashboardView(dependencies: .mock(), navigation: TabNavigationState())
    }
}

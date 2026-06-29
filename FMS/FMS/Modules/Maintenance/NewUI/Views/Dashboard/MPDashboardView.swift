import Combine
import SwiftUI

struct MPDashboardView: View {
    @StateObject private var viewModel: MPDashboardViewModel
    @ObservedObject private var navigation: TabNavigationState

    @Environment(\.scenePhase) private var scenePhase
    @State private var isShowingProfile = false
    @State private var workOrderToStart: WorkOrder.ID?
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
                    progressSection
                    servicesSection
                    activitySection
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, AppSpacing.large)
            .padding(.bottom, 60)
        }
        .background(AppColor.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar) // Hide navigation bar to match design
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
    }
    
    private func isPaused(workOrderID: WorkOrder.ID?) -> Bool {
        guard let id = workOrderID else { return false }
        return viewModel.upcomingWorkOrders.first(where: { $0.workOrder.id == id })?.workOrder.status == .inProgress
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
    


    private var progressSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text("Overview")
                .font(AppTypography.title)
                .foregroundStyle(AppColor.textPrimary)
            
            HStack(spacing: AppSpacing.small) {
                progressCard(title: "On Going", value: "\(viewModel.inProgressCount)", color: AppColor.warning)
                progressCard(title: "Completed", value: "\(viewModel.completedCount)", color: AppColor.success)
                progressCard(title: "Remaining", value: "\(viewModel.remainingCount)", color: AppColor.brand)
            }
        }
    }
    
    private func progressCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(AppTypography.largeTitle)
                .foregroundStyle(color)
            Text(title)
                .font(AppTypography.caption)
                .foregroundStyle(AppColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        )
    }

    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            sectionHeaderWithAction(title: "Scheduled", actionTitle: "View All") {
                navigation.push(.upcomingMaintenanceList)
            }
            
            if viewModel.upcomingWorkOrders.isEmpty {
                MPEmptyStateView(title: "No Scheduled Tasks", message: "Scheduled tasks will appear here.", systemImage: FleetIcon.calendar)
            } else {
                VStack(spacing: 0) {
                    let items = Array(viewModel.upcomingWorkOrders.prefix(5))
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        Button {
                            // Optionally push to job summary
                        } label: {
                            workOrderRow(for: item, isLast: index == items.count - 1)
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
        .alert(
            isPaused(workOrderID: workOrderToStart) ? "Continue Work Order" : "Start Work Order",
            isPresented: Binding(
                get: { workOrderToStart != nil },
                set: { if !$0 { workOrderToStart = nil } }
            ),
            actions: {
                Button("Cancel", role: .cancel) {
                    workOrderToStart = nil
                }
                Button(isPaused(workOrderID: workOrderToStart) ? "Continue" : "Start") {
                    if let id = workOrderToStart {
                        DispatchQueue.main.async {
                            navigation.push(.completeWorkOrder(workOrderID: id))
                        }
                    }
                }
            },
            message: {
                Text(isPaused(workOrderID: workOrderToStart) ? "Are you ready to resume this work order?" : "Are you ready to start this work order? The timer will begin.")
            }
        )
    }

    private func workOrderRow(for dashboardOrder: DashboardWorkOrder, isLast: Bool) -> some View {
        let workOrder = dashboardOrder.workOrder
        let vehicle = dashboardOrder.vehicle
        let vehicleDisplay = vehicle?.registrationNumber ?? vehicle?.name ?? "Unknown"
        let isPaused = workOrder.status == .inProgress
        
        return VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: vehicle?.sfSymbolName ?? FleetIcon.car)
                    .font(.title3)
                    .foregroundStyle(AppColor.brand)
                    .frame(width: 44, height: 28)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(vehicleDisplay)
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColor.textPrimary)
                    
                    Text(workOrder.title)
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColor.textSecondary)
                        .lineLimit(2)
                    
                    HStack(spacing: 4) {
                        Image(systemName: FleetIcon.calendar)
                            .font(AppTypography.footnote)
                            .foregroundStyle(workOrder.isUrgent == true ? Color.red : Color.gray)
                        Text("Due: \(workOrder.dueDate.formatted(.dateTime.month(.abbreviated).day().year()))")
                            .font(AppTypography.footnote)
                            .foregroundStyle(workOrder.isUrgent == true ? Color.red : Color.gray)
                    }
                }
                
                Spacer()
                
                Button {
                    workOrderToStart = workOrder.id
                } label: {
                    ZStack {
                        Circle()
                            .fill(isPaused ? Color.orange.opacity(0.15) : Color.green.opacity(0.15))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: isPaused ? "pause.fill" : "play.fill")
                            .font(.headline)
                            .foregroundStyle(isPaused ? Color.orange.opacity(0.7) : Color.green.opacity(0.7))
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, AppSpacing.medium)
            .padding(.horizontal, 16)
            
            if !isLast {
                Divider()
                    .padding(.leading, 44 + 12 + 16)
                    .padding(.trailing, 16)
            }
        }
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            sectionHeaderWithAction(title: "Activity History", actionTitle: "See All") {
                navigation.push(.activityHistory)
            }
            
            // Timeline Card
            VStack(alignment: .leading, spacing: 0) {
                let filteredActivities = viewModel.activities.filter { $0.status == .completed || $0.status == .inProgress }
                let items = filteredActivities.prefix(3).map { activity -> MaintenanceTimelineItem in
                    let status: TimelineStatus = activity.status == .completed ? .done : .paused
                    let sfSymbol = activity.status == .completed ? FleetIcon.checkmark : "pause.circle.fill"
                    
                    let formatter = DateFormatter()
                    if Calendar.current.isDateInToday(activity.date) {
                        formatter.dateFormat = "'Today •' HH:mm"
                    } else {
                        formatter.dateFormat = "MMM d '•' HH:mm"
                    }
                    let dateStr = formatter.string(from: activity.date)
                    
                    let elapsedStr: String?
                    if let elapsed = activity.elapsedTime, elapsed > 0 {
                        let hours = Int(elapsed) / 3600
                        let minutes = (Int(elapsed) % 3600) / 60
                        let seconds = Int(elapsed) % 60
                        
                        if hours > 0 {
                            elapsedStr = "\(hours)h \(minutes)m"
                        } else if minutes > 0 {
                            elapsedStr = "\(minutes)m \(seconds)s"
                        } else {
                            elapsedStr = "\(seconds)s"
                        }
                    } else {
                        elapsedStr = nil
                    }
                    
                    return MaintenanceTimelineItem(dateStr: dateStr, elapsedStr: elapsedStr, title: activity.title, subtitle: activity.subtitle, status: status, sfSymbol: sfSymbol)
                }
                
                if items.isEmpty {
                    MPEmptyStateView(title: "Nothing is done yet", message: "Your recent activities will appear here.", systemImage: "clock")
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                            maintenanceTimelineRow(item, isLast: index == items.count - 1)
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.white)
                            .shadow(color: AppColor.textPrimary.opacity(0.06), radius: 8, x: 0, y: 4)
                    )
                }
            }

        }
    }

    private func maintenanceTimelineRow(_ item: MaintenanceTimelineItem, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline line & icon
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(item.status.color.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: item.sfSymbol)
                        .font(AppTypography.caption.weight(.bold))
                        .foregroundStyle(item.status.color)
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center) {
                    Text(item.dateStr)
                        .font(AppTypography.caption.weight(.semibold))
                        .foregroundStyle(item.status.color)
                    Spacer()
                }
                
                Text(item.title)
                    .font(AppTypography.callout.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
                    
                if let elapsed = item.elapsedStr {
                    Text("Worked for \(elapsed)")
                        .font(AppTypography.caption)
                        .foregroundStyle(.gray)
                }
            }
            .padding(.bottom, 16)
        }
        .fixedSize(horizontal: false, vertical: true)
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

enum TimelineStatus {
    case done, paused, now, next
    
    var color: Color {
        switch self {
        case .done: return Color.green
        case .paused: return Color.orange
        case .now: return Color.blue
        case .next: return Color.gray
        }
    }
    
    var badgeText: String {
        switch self {
        case .done: return "Done"
        case .paused: return "Paused"
        case .now: return "Now"
        case .next: return "Next"
        }
    }
}

struct MaintenanceTimelineItem {
    let dateStr: String
    let elapsedStr: String?
    let title: String
    let subtitle: String
    let status: TimelineStatus
    let sfSymbol: String
}

#Preview {
    NavigationStack {
        MPDashboardView(dependencies: .mock(), navigation: TabNavigationState())
    }
}

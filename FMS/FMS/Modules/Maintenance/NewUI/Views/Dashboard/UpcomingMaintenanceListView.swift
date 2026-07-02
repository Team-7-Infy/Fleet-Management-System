import SwiftUI

struct UpcomingMaintenanceListView: View {
    @StateObject private var viewModel: UpcomingMaintenanceListViewModel
    private let navigation: TabNavigationState
    
    @State private var workOrderToStart: WorkOrder.ID?
    
    init(dependencies: AppDependencyContainer, navigation: TabNavigationState) {
        self._viewModel = StateObject(wrappedValue: UpcomingMaintenanceListViewModel(dependencies: dependencies))
        self.navigation = navigation
    }
    
    var body: some View {
        contentView
            .navigationTitle("Scheduled")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.load()
            }
            .refreshable {
                await viewModel.load(isRefresh: true)
            }
            .alert("Start Work Order", isPresented: Binding(
            get: { workOrderToStart != nil },
            set: { if !$0 { workOrderToStart = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                workOrderToStart = nil
            }
            Button("Start") {
                if let id = workOrderToStart {
                    DispatchQueue.main.async {
                        navigation.push(.completeWorkOrder(workOrderID: id))
                    }
                }
                workOrderToStart = nil
            }
        } message: {
            Text("Do you want to start this work order?")
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let error):
            VStack(spacing: 16) {
                Image(systemName: FleetIcon.warning)
                    .font(.largeTitle)
                    .foregroundColor(.red)
                Text("Failed to load")
                    .font(AppTypography.headline)
                Text(error.localizedDescription)
                    .font(AppTypography.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Button("Retry") {
                    Task { await viewModel.load() }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(_):
            loadedView
        }
    }
    
    @ViewBuilder
    private var loadedView: some View {
        ScrollView {
            if viewModel.weeklySchedule.isEmpty {
                Text("No scheduled tasks")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, AppSpacing.xxLarge)
            } else {
                VStack(alignment: .leading, spacing: AppSpacing.large) {
                    ForEach(viewModel.weeklySchedule) { day in
                        VStack(alignment: .leading, spacing: AppSpacing.small) {
                            Text(day.dayName)
                                .font(AppTypography.title)
                                .foregroundStyle(AppColor.textPrimary)
                                .padding(.horizontal, AppSpacing.small)
                            
                            VStack(spacing: 0) {
                                ForEach(Array(day.workOrders.enumerated()), id: \.element.id) { index, order in
                                    Button {
                                        // Do nothing or navigate to job summary if implemented later
                                    } label: {
                                        workOrderRow(for: order, isLast: index == day.workOrders.count - 1)
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
                .padding(.horizontal, AppSpacing.large)
                .padding(.vertical, AppSpacing.large)
            }
        }
        .background(AppColor.background.ignoresSafeArea())
    }
    
    private func workOrderRow(for dashboardOrder: DashboardWorkOrder, isLast: Bool) -> some View {
        let workOrder = dashboardOrder.workOrder
        let vehicle = dashboardOrder.vehicle
        let vehicleDisplay = vehicle != nil ? "\(vehicle!.make) \(vehicle!.model)" : "Unknown"
        
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
                            .fill(Color.green.opacity(0.15))
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: "play.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.green.opacity(0.7))
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
}

#Preview {
    NavigationStack {
        UpcomingMaintenanceListView(dependencies: .mock(), navigation: TabNavigationState())
    }
}

import SwiftUI

struct AllHistoryWorkOrdersView: View {
    let dependencies: AppDependencyContainer
    let navigation: TabNavigationState
    @StateObject private var viewModel: MPDashboardViewModel

    init(dependencies: AppDependencyContainer, navigation: TabNavigationState) {
        self.dependencies = dependencies
        self.navigation = navigation
        _viewModel = StateObject(wrappedValue: MPDashboardViewModel(dependencies: dependencies))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                if viewModel.state.isLoading {
                    LoadingView(title: "Loading History")
                } else if viewModel.completedWorkOrders.isEmpty {
                    MPEmptyStateView(title: "No History", message: "You don't have any completed tasks.", systemImage: "clock")
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.completedWorkOrders.enumerated()), id: \.element.id) { index, item in
                            Button {
                                navigation.push(.pastWorkOrderDetails(workOrderID: item.workOrder.id))
                            } label: {
                                workOrderRow(for: item, isLast: index == viewModel.completedWorkOrders.count - 1)
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
            .padding()
        }
        .background(AppColor.background.ignoresSafeArea())
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task { await viewModel.load() }
        }
    }
    
    private func workOrderRow(for dashboardOrder: DashboardWorkOrder, isLast: Bool) -> some View {
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
}

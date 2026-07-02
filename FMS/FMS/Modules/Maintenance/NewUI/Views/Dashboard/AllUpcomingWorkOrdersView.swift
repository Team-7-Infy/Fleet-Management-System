import SwiftUI

struct AllUpcomingWorkOrdersView: View {
    let dependencies: AppDependencyContainer
    let navigation: TabNavigationState
    @StateObject private var viewModel: MPDashboardViewModel
    @State private var workOrderToStart: WorkOrder.ID? = nil

    init(dependencies: AppDependencyContainer, navigation: TabNavigationState) {
        self.dependencies = dependencies
        self.navigation = navigation
        _viewModel = StateObject(wrappedValue: MPDashboardViewModel(dependencies: dependencies))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                if viewModel.state.isLoading {
                    LoadingView(title: "Loading Upcoming Tasks")
                } else if viewModel.upcomingWorkOrdersFiltered.isEmpty {
                    MPEmptyStateView(title: "No Upcoming Tasks", message: "You don't have any upcoming tasks scheduled.", systemImage: FleetIcon.calendar)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.upcomingWorkOrdersFiltered.enumerated()), id: \.element.id) { index, item in
                            Button {
                                // push to summary
                            } label: {
                                workOrderRow(for: item, isLast: index == viewModel.upcomingWorkOrdersFiltered.count - 1, showDate: true)
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
        .navigationTitle("Upcoming")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task { await viewModel.load() }
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
                    navigation.push(.completeWorkOrder(workOrderID: id))
                }
                workOrderToStart = nil
            }
        } message: {
            Text("Do you want to start this work order?")
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
}

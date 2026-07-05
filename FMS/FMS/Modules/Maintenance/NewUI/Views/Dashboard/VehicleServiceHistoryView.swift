import SwiftUI

struct VehicleServiceHistoryView: View {
    @StateObject private var viewModel: VehicleDetailsViewModel
    @ObservedObject private var navigation: TabNavigationState

    init(vehicleID: Vehicle.ID, dependencies: AppDependencyContainer, navigation: TabNavigationState) {
        _viewModel = StateObject(wrappedValue: VehicleDetailsViewModel(vehicleID: vehicleID, dependencies: dependencies))
        self.navigation = navigation
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                if viewModel.state.isLoading {
                    LoadingView(title: "Loading history")
                } else {
                    recentServices
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, AppSpacing.large)
            .padding(.bottom, AppSpacing.large)
        }
        .background(AppColor.background.ignoresSafeArea())
        .navigationTitle("Service History")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await viewModel.load()
            }
        }
    }

    private func formatWorkOrderDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    private var recentServices: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            if viewModel.completedWorkOrders.isEmpty {
                MPEmptyStateView(title: "No Service History", message: "This vehicle has no completed service records.", systemImage: "tray")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.completedWorkOrders.enumerated()), id: \.element.id) { index, workOrder in
                        Button(action: {
                            navigation.push(.pastWorkOrderDetails(workOrderID: workOrder.id))
                        }) {
                            serviceRow(
                                title: workOrder.title, 
                                date: formatWorkOrderDate(workOrder.dueDate), 
                                icon: "wrench.fill", 
                                showDivider: index < viewModel.completedWorkOrders.count - 1
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                )
            }
        }
    }
    
    private func serviceRow(title: String, date: String, icon: String, showDivider: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(Color.blue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColor.textPrimary)
                    Text(date)
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColor.textSecondary)
                }

                Spacer()

                Text("Completed")
                    .font(AppTypography.caption.weight(.semibold))
                    .foregroundStyle(Color.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.15), in: Capsule())
                
                Image(systemName: FleetIcon.chevronRight)
                    .font(AppTypography.callout)
                    .foregroundStyle(Color.gray.opacity(0.6))
                    .padding(.leading, 4)
            }
            .padding(16)

            if showDivider {
                Divider()
                    .padding(.horizontal, 16)
            }
        }
    }
}

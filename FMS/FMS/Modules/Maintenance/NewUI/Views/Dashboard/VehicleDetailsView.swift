import SwiftUI

struct VehicleDetailsView: View {
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
                    LoadingView(title: "Loading vehicle")
                } else if let vehicle = viewModel.vehicle {
                    unifiedCard(for: vehicle)
                    recentServices
                } else {
                    MPEmptyStateView(title: "Vehicle Unavailable", message: "This vehicle could not be loaded.", systemImage: AppIcon.vehicle)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, AppSpacing.large)
            .padding(.bottom, AppSpacing.large)
        }
        .background(AppColor.background.ignoresSafeArea())
        .navigationTitle("Vehicle Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await viewModel.load()
            }
        }
    }

    private func unifiedCard(for vehicle: Vehicle) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .center, spacing: 16) {
                VehicleAssetImage(vehicle: vehicle, width: 96, height: 68, cornerRadius: 16)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(vehicle.name)
                        .font(AppTypography.title)
                        .foregroundStyle(AppColor.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer()
            }
            .padding(16)
            
            Divider()
            
            // Horizontal Details Section
            HStack(alignment: .center) {

                
                horizontalDetailItem(icon: "box.truck", title: "Type", value: vehicle.vehicleType.isEmpty ? "Unknown" : vehicle.vehicleType)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        )
    }

    private func horizontalDetailItem(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppColor.brand.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColor.brand)
            }
            
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColor.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(value)
                    .font(AppTypography.callout.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    

    private func formatWorkOrderDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    private var recentServices: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text("Recent Service History")
                .font(AppTypography.title)
            
            if viewModel.completedWorkOrders.isEmpty {
                Text("No recent services")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColor.textSecondary)
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
                        .fill(AppColor.inProgress.opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(AppColor.inProgress)
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
                    .foregroundStyle(AppColor.success)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppColor.success.opacity(0.15), in: Capsule())
                
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

#Preview {
    NavigationStack {
        VehicleDetailsView(vehicleID: PreviewData.vehicles[0].id, dependencies: .mock(), navigation: TabNavigationState())
    }
}

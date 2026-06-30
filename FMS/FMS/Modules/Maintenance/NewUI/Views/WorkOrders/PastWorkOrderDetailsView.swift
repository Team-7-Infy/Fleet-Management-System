import SwiftUI

struct PastWorkOrderDetailsView: View {
    let workOrderID: WorkOrder.ID
    let dependencies: AppDependencyContainer
    @ObservedObject var navigation: TabNavigationState
    
    @StateObject private var viewModel: PastWorkOrderDetailsViewModel
    
    init(workOrderID: WorkOrder.ID, dependencies: AppDependencyContainer, navigation: TabNavigationState) {
        self.workOrderID = workOrderID
        self.dependencies = dependencies
        self.navigation = navigation
        _viewModel = StateObject(wrappedValue: PastWorkOrderDetailsViewModel(workOrderID: workOrderID, dependencies: dependencies))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.large) {
                if viewModel.state.isLoading {
                    LoadingView(title: "Loading work order details")
                } else if let workOrder = viewModel.workOrder {
                    summaryCards(for: workOrder)
                } else {
                    MPEmptyStateView(title: "Error", message: "Could not load work order details.", systemImage: "xmark.octagon")
                }
            }
            .padding(AppSpacing.large)
        }
        .background(AppColor.background.ignoresSafeArea())
        .navigationTitle("Work Order Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
    }
    
    private func summaryCards(for workOrder: WorkOrder) -> some View {
        VStack(spacing: 16) {
            // Card 1: Work Order Name & Status
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("WORK ORDER")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.gray)
                    Text(workOrder.title)
                        .font(.system(size: 16, weight: .bold))
                }
                Spacer()
                Text(workOrder.status == .completed ? "COMPLETED" : workOrder.status.title.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .foregroundStyle(Color.blue)
                    .clipShape(Capsule())
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
            .shadow(color: Color.black.opacity(0.02), radius: 8, x: 0, y: 4)

            // Card 2: Labor & Parts
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "clock")
                        .foregroundStyle(Color.blue)
                    Text("Labor Time")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Text(viewModel.formattedLaborTime)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.gray)
                }
                
                let parts = viewModel.usedParts
                if !parts.isEmpty {
                    Divider()
                    HStack {
                        Image(systemName: "wrench.adjustable")
                            .foregroundStyle(Color.blue)
                        Text("Parts Used")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(parts, id: \.id) { part in
                                HStack(spacing: 4) {
                                    Image(systemName: "gearshape")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color.blue)
                                    Text("\(part.name) x\(part.quantity)")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.black.opacity(0.7))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.gray.opacity(0.1))
                                .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
            .shadow(color: Color.black.opacity(0.02), radius: 8, x: 0, y: 4)

            // Card 3: Total Cost
            HStack {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 32, height: 32)
                        Image(systemName: "banknote")
                            .foregroundStyle(Color.blue)
                            .font(.system(size: 14))
                    }
                    Text("Total Cost")
                        .font(.system(size: 16, weight: .bold))
                }
                Spacer()
                Text(viewModel.formattedTotalCost)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.blue)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
            .shadow(color: Color.black.opacity(0.02), radius: 8, x: 0, y: 4)
        }
    }
}

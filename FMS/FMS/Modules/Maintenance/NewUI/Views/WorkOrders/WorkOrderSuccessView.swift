import SwiftUI

struct WorkOrderSuccessView: View {
    let workOrderID: WorkOrder.ID
    let elapsedTime: TimeInterval
    let parts: [PartItem]
    let laborCost: Decimal
    let dependencies: AppDependencyContainer
    @ObservedObject var navigation: TabNavigationState
    
    @StateObject private var viewModel: WorkOrderSuccessViewModel
    @State private var isAnimating = false
    
    init(workOrderID: WorkOrder.ID, elapsedTime: TimeInterval, parts: [PartItem], laborCost: Decimal, dependencies: AppDependencyContainer, navigation: TabNavigationState) {
        self.workOrderID = workOrderID
        self.elapsedTime = elapsedTime
        self.parts = parts
        self.laborCost = laborCost
        self.dependencies = dependencies
        self.navigation = navigation
        _viewModel = StateObject(wrappedValue: WorkOrderSuccessViewModel(workOrderID: workOrderID, elapsedTime: elapsedTime, parts: parts, laborCost: laborCost, dependencies: dependencies))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.large) {
                if viewModel.state.isLoading {
                    LoadingView(title: "Loading summary")
                } else if let workOrder = viewModel.workOrder {
                    successHero
                    summaryCards(for: workOrder)

                    PrimaryButton(title: "Back to Dashboard", systemImage: "house") {
                        navigation.popToRoot()
                    }
                    .padding(.top, 8)
                } else {
                    MPEmptyStateView(title: "Error", message: "Could not load work order.", systemImage: "xmark.octagon")
                }
            }
            .padding(AppSpacing.large)
        }
        .background(AppColor.background.ignoresSafeArea())
        .navigationTitle("Success")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .task {
            await viewModel.load()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.2)) {
                isAnimating = true
            }
        }
    }

    private var successHero: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 72, height: 72)
                Image(systemName: "checkmark")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(isAnimating ? 1.0 : 0.5)
            .opacity(isAnimating ? 1.0 : 0.0)

            VStack(spacing: 4) {
                Text("Work Order Completed")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 16)
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
                Text("COMPLETED")
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

#Preview {
    NavigationStack {
        WorkOrderSuccessView(workOrderID: PreviewData.workOrders[0].id, elapsedTime: 3600, parts: [], laborCost: 0, dependencies: .mock(), navigation: TabNavigationState())
    }
}

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
            // Card 1: Work ID, Title, Description
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.blue)
                    }
                    
                    Text("#\(workOrder.id.uuidString.prefix(8).uppercased())")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.blue)
                    
                    Spacer()
                    
                    Text(workOrder.status == .completed ? "COMPLETED" : workOrder.status.title.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(Color.blue)
                        .clipShape(Capsule())
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(workOrder.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppColor.textPrimary)
                        .lineLimit(2)
                    
                    Text(workOrder.description)
                        .font(.system(size: 14))
                        .foregroundStyle(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
            .shadow(color: Color.black.opacity(0.02), radius: 8, x: 0, y: 4)

            // Card 2: Summary Card
            VStack(alignment: .leading, spacing: 16) {
                Text("SUMMARY")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.gray)
                
                // Parts Used
                let parts = viewModel.usedParts
                if !parts.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Parts Used")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.gray)
                            Spacer()
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
                    Divider()
                }
                
                // Costs & Time
                VStack(spacing: 12) {
                    HStack {
                        Text("Labour Time")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.gray)
                        Spacer()
                        Text(viewModel.formattedLaborTime)
                            .font(.system(size: 14, weight: .bold))
                    }
                    
                    HStack {
                        Text("Parts Cost")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.gray)
                        Spacer()
                        Text(viewModel.formattedPartsCost)
                            .font(.system(size: 14, weight: .bold))
                    }
                    
                    HStack {
                        Text("Labour Cost")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.gray)
                        Spacer()
                        Text(viewModel.formattedLaborCost)
                            .font(.system(size: 14, weight: .bold))
                    }
                }
                
                Divider()
                
                HStack {
                    Text("Total Cost")
                        .font(.system(size: 16, weight: .bold))
                    Spacer()
                    Text(viewModel.formattedTotalCost)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Color.blue)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
            .shadow(color: Color.black.opacity(0.02), radius: 8, x: 0, y: 4)
            
            // Card 3: Remarks
            if let remarks = workOrder.remarks, !remarks.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "text.bubble.fill")
                            .foregroundStyle(Color.blue)
                        Text("Remarks")
                            .font(.system(size: 14, weight: .bold))
                        Spacer()
                    }
                    Text(remarks)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.gray)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
                .shadow(color: Color.black.opacity(0.02), radius: 8, x: 0, y: 4)
            }
        }
    }
}

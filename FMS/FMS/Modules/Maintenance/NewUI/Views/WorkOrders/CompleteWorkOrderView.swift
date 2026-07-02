import SwiftUI

struct CompleteWorkOrderView: View {
    @StateObject private var viewModel: CompleteWorkOrderViewModel
    @ObservedObject private var navigation: TabNavigationState
    @State private var showingAddPartsSheet = false
    let dependencies: AppDependencyContainer

    init(workOrderID: WorkOrder.ID, dependencies: AppDependencyContainer, navigation: TabNavigationState) {
        _viewModel = StateObject(wrappedValue: CompleteWorkOrderViewModel(workOrderID: workOrderID, dependencies: dependencies))
        self.navigation = navigation
        self.dependencies = dependencies
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.state.isLoading {
                LoadingView(title: "Loading summary...")
            } else if let workOrder = viewModel.workOrder {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        // 1. Top Card: Issue & Timer
                        VStack(spacing: 16) {
                            HStack(alignment: .center, spacing: 16) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(AppColor.inProgress.opacity(0.1))
                                        .frame(width: 48, height: 48)
                                    
                                    Image(systemName: "power.circle")
                                        .font(.system(size: 24))
                                        .foregroundStyle(AppColor.inProgress)
                                }
                                
                                Text(workOrder.title)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(AppColor.textPrimary)
                                    .lineLimit(2)
                                
                                Spacer()
                            }
                            
                            Divider()
                                .padding(.horizontal, 8)
                            
                            // Timer centered below
                            VStack(alignment: .center, spacing: 4) {
                                Text("ELAPSED TIME")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(AppColor.textSecondary)
                                
                                Text(formatTime(viewModel.elapsedTime))
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(AppColor.success)
                            }
                            .padding(.bottom, 4)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
                        )
                        
                        // History of Vehicle Button
                        Button(action: {
                            navigation.push(.vehicleDetails(vehicleID: workOrder.vehicleID))
                        }) {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                Text("History of Vehicle")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .padding()
                            .foregroundStyle(AppColor.inProgress)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AppColor.inProgress.opacity(0.1))
                            )
                        }
                        
                        // 2. Parts Used Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Parts Used")
                                    .font(.system(size: 16, weight: .bold))
                                Spacer()
                                Button(action: { showingAddPartsSheet = true }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus")
                                        Text("Add Part")
                                    }
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(AppColor.inProgress)
                                }
                            }
                            
                            // Parts List
                            ForEach(viewModel.usedParts) { part in
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack(alignment: .top) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(part.name)
                                                    .font(.system(size: 14, weight: .bold))
                                                    .fixedSize(horizontal: false, vertical: true)
                                                Text(part.id)
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(Color.gray)
                                            }
                                            
                                            Spacer()
                                            
                                            // Amount & Unit Price
                                            VStack(alignment: .trailing, spacing: 4) {
                                                Text("₹\(formatDecimal(part.amount))")
                                                    .font(.system(size: 14, weight: .bold))
                                                
                                                Text("₹\(formatDecimal(part.unitPrice))/ea")
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(Color.gray)
                                            }
                                        }
                                        
                                        HStack {
                                            // Stepper
                                            HStack(spacing: 16) {
                                                Button(action: { viewModel.decrementPart(id: part.id) }) {
                                                    Image(systemName: "minus")
                                                        .foregroundStyle(Color.gray)
                                                        .font(.system(size: 12, weight: .semibold))
                                                        .frame(width: 24, height: 24)
                                                }
                                                Text("\(part.quantity)")
                                                    .font(.system(size: 14, weight: .bold))
                                                Button(action: { viewModel.incrementPart(id: part.id) }) {
                                                    Image(systemName: "plus")
                                                        .foregroundStyle(Color.gray)
                                                        .font(.system(size: 12, weight: .semibold))
                                                        .frame(width: 24, height: 24)
                                                }
                                            }
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 2)
                                            .background(RoundedRectangle(cornerRadius: 16).fill(Color(white: 0.95)))
                                            
                                            Spacer()
                                                
                                            Button(action: { viewModel.removePart(id: part.id) }) {
                                                Image(systemName: "trash")
                                                    .foregroundStyle(AppColor.destructive)
                                                    .font(.system(size: 16))
                                                    .padding(8)
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                                
                                if part.id != viewModel.usedParts.last?.id {
                                    Divider()
                                }
                            }
                            
                            Divider()
                            
                            HStack {
                                Spacer()
                                Text("TOTAL PARTS COST")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.gray)
                                Text("₹\(formatDecimal(viewModel.totalPartsCost))")
                                    .font(.system(size: 16, weight: .bold))
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
                        )
                        
                        // 3. Labour Cost
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Labour Cost")
                                .font(.system(size: 14, weight: .bold))
                            
                            HStack {
                                Text("₹")
                                    .font(.system(size: 16))
                                TextField("", text: $viewModel.laborCost)
                                    .font(.system(size: 16, weight: .bold))
                                    .keyboardType(.decimalPad)
                                
                                if !viewModel.laborCost.isEmpty {
                                    Button(action: { viewModel.laborCost = "" }) {
                                        Image(systemName: "xmark.circle")
                                            .foregroundStyle(Color.gray)
                                    }
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            
                            Text("Enter the total labour/service cost incurred.")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.gray)
                        }
                        
                        // 4. Remarks
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 4) {
                                Text("Remarks")
                                    .font(.system(size: 14, weight: .bold))
                                Text("(Optional)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.gray)
                            }
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                TextEditor(text: $viewModel.remarks)
                                    .font(.system(size: 14))
                                    .frame(height: 80)
                                    .padding(8)
                                    .scrollContentBackground(.hidden)
                                
                                Text("\(viewModel.remarks.count)/250")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.gray)
                                    .padding(.trailing, 8)
                                    .padding(.bottom, 8)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        }
                        
                        // 5. Summary
                        VStack(spacing: 12) {
                            Text("SUMMARY")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.gray)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                            HStack {
                                Text("Parts Cost")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.gray)
                                Spacer()
                                Text("₹\(formatDecimal(viewModel.totalPartsCost))")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            HStack {
                                Text("Labour Cost")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.gray)
                                Spacer()
                                Text("₹\(formatDecimal(viewModel.totalLaborCost))")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            
                            Divider()
                            
                            HStack {
                                Text("Total Cost")
                                    .font(.system(size: 16, weight: .bold))
                                Spacer()
                                Text("₹\(formatDecimal(viewModel.totalCost))")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(AppColor.inProgress)
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
                        )
                        
                        // 6. Action Buttons at end of ScrollView
                        HStack(spacing: 16) {
                            Button(action: {
                                Task {
                                    await viewModel.pauseAndExit()
                                    await MainActor.run {
                                        navigation.pop()
                                    }
                                }
                            }) {
                                Text("Pause & Exit")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Color.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(AppColor.destructive)
                                    .clipShape(Capsule())
                            }
                            
                            Button(action: {
                                Task {
                                    await viewModel.completeWorkOrder()
                                    if let id = viewModel.workOrder?.id {
                                        await MainActor.run {
                                            navigation.push(.workOrderSuccess(workOrderID: id, elapsedTime: viewModel.elapsedTime, parts: viewModel.usedParts, laborCost: viewModel.totalLaborCost))
                                        }
                                    }
                                }
                            }) {
                                Text("Complete")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Color.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(AppColor.success)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.top, 8)
                        
                    }
                    .padding(24)
                }
            } else {
                MPEmptyStateView(title: "Not Found", message: "Work order details could not be loaded.", systemImage: AppIcon.workOrder)
            }
        }
        .background(AppColor.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack {
                    Text("Complete Work Order")
                        .font(.system(size: 16, weight: .bold))
                    if let id = viewModel.workOrder?.id {
                        Text(id.uuidString.prefix(8).uppercased())
                            .font(.system(size: 10))
                            .foregroundStyle(.gray)
                    }
                }
            }
        }
        .task {
            await viewModel.load()
        }
        .onDisappear {
            viewModel.stopTimer()
            if !viewModel.wasCompleted && !viewModel.wasExplicitlyPaused && viewModel.elapsedTime > 0 {
                Task {
                    await viewModel.saveWorkProgress()
                }
            }
        }
        .sheet(isPresented: $showingAddPartsSheet) {
            AddPartsSheet(dependencies: dependencies, usedParts: viewModel.usedParts, vehicleType: viewModel.currentVehicleType) { part, qty in
                viewModel.addPart(part, quantity: qty)
            }
        }
        .alert("Notice", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred.")
        }
    }
    
    private func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    private func formatDecimal(_ decimal: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: decimal as NSDecimalNumber) ?? "0"
    }
}

#Preview {
    NavigationStack {
        CompleteWorkOrderView(workOrderID: PreviewData.workOrders[0].id, dependencies: .mock(), navigation: TabNavigationState())
    }
}

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
                        
                        // 1. Top Card: Issue Details
                        VStack(alignment: .leading, spacing: 12) {

                            VStack(alignment: .leading, spacing: 6) {
                                Text(workOrder.title)
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.black)
                                    .lineLimit(2)
                                
                                Text(workOrder.description)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.gray)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                        )
                        
                        // Attached Photos
                        if let photoUrls = workOrder.photoUrls, !photoUrls.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Attached Photos")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.black)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(photoUrls, id: \.self) { urlString in
                                            AsyncImage(url: URL(string: urlString)) { image in
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                            } placeholder: {
                                                Rectangle()
                                                    .fill(Color(hex: 0xE8EAED))
                                                    .overlay(
                                                        Image(systemName: "photo")
                                                            .foregroundStyle(Color.gray)
                                                    )
                                            }
                                            .frame(width: 100, height: 100)
                                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                        }
                                    }
                                }
                            }
                        }
                        
                        // 2. Parts Used Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Parts Used")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.black)
                                Spacer()
                                Button(action: { showingAddPartsSheet = true }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 24))
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
                                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                                    .foregroundStyle(Color.black)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                            
                                            Spacer()
                                            
                                            // Amount & Unit Price
                                            VStack(alignment: .trailing, spacing: 4) {
                                                Text("₹\(formatDecimal(part.amount))")
                                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                                    .foregroundStyle(Color.black)
                                                
                                                Text("₹\(formatDecimal(part.unitPrice))/ea")
                                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                                    .foregroundStyle(Color.gray)
                                            }
                                        }
                                        
                                        HStack {
                                            // Stepper
                                            HStack(spacing: 16) {
                                                Button(action: { viewModel.decrementPart(id: part.id) }) {
                                                    Image(systemName: "minus")
                                                        .foregroundStyle(Color.gray)
                                                        .font(.system(size: 12, weight: .bold))
                                                        .frame(width: 24, height: 24)
                                                }
                                                Text("\(part.quantity)")
                                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                                Button(action: { viewModel.incrementPart(id: part.id) }) {
                                                    Image(systemName: "plus")
                                                        .foregroundStyle(Color.black)
                                                        .font(.system(size: 12, weight: .bold))
                                                        .frame(width: 24, height: 24)
                                                }
                                            }
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 4)
                                            .background(Color(hex: 0xE8EAED))
                                            .clipShape(Capsule())
                                            
                                            Spacer()
                                                
                                            Button(action: { viewModel.removePart(id: part.id) }) {
                                                Image(systemName: "trash.fill")
                                                    .foregroundStyle(AppColor.destructive.opacity(0.8))
                                                    .font(.system(size: 16))
                                                    .padding(8)
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                                
                                if part.id != viewModel.usedParts.last?.id {
                                    Divider().opacity(0.5)
                                }
                            }
                            
                            Divider().opacity(0.5)
                            
                            HStack {
                                Spacer()
                                Text("TOTAL PARTS COST")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.gray)
                                Text("₹\(formatDecimal(viewModel.totalPartsCost))")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.black)
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                        )
                        
                        // 3. Labour Cost
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Labour Cost")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.black)
                            
                            HStack {
                                Text("₹")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(Color.gray)
                                
                                Text(viewModel.laborCost.isEmpty ? "0.00" : viewModel.laborCost)
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.black)
                                
                                Spacer()
                                
                                Text(formatTime(viewModel.elapsedTime))
                                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(Color.gray)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(hex: 0xE8EAED))
                                    .clipShape(Capsule())
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color(hex: 0xE8EAED), lineWidth: 1)
                            )
                            
                            Text("Calculated: hourly rate of ₹\(Int(viewModel.hourlyRate))/hr × \(String(format: "%.3f", viewModel.elapsedTime / 3600.0)) hrs.")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.gray)
                        }
                        
                        // 4. Remarks
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 4) {
                                Text("Remarks")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.black)
                                Text("(Optional)")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.gray)
                            }
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                TextEditor(text: $viewModel.remarks)
                                    .font(.system(size: 15, design: .rounded))
                                    .frame(height: 100)
                                    .padding(12)
                                    .scrollContentBackground(.hidden)
                                
                                Text("\(viewModel.remarks.count)/250")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.gray)
                                    .padding(.trailing, 12)
                                    .padding(.bottom, 12)
                            }
                            .background(Color(hex: 0xE8EAED))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        
                        // 5. Summary
                        VStack(spacing: 16) {
                            Text("SUMMARY")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.gray)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                            HStack {
                                Text("Parts Cost")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.gray)
                                Spacer()
                                Text("₹\(formatDecimal(viewModel.totalPartsCost))")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.black)
                            }
                            HStack {
                                Text("Labour Cost")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.gray)
                                Spacer()
                                Text("₹\(formatDecimal(viewModel.totalLaborCost))")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.black)
                            }
                            
                            Divider().opacity(0.5)
                            
                            HStack {
                                Text("Total Cost")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.black)
                                Spacer()
                                Text("₹\(formatDecimal(viewModel.totalCost))")
                                    .font(.system(size: 28, weight: .black, design: .rounded))
                                    .foregroundStyle(AppColor.inProgress)
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                        )
                        
                        // 6. Action Buttons at end of ScrollView
                        HStack(spacing: 16) {
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
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(AppColor.success)
                                    .clipShape(Capsule())
                                    .shadow(color: AppColor.success.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                        }
                        .padding(.top, 16)
                        
                    }
                    .padding(24)
                }
            } else {
                MPEmptyStateView(title: "Not Found", message: "Work order details could not be loaded.", systemImage: AppIcon.workOrder)
            }
        }
        .background(Color(hex: 0xF4F5F9).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Complete Work Order")
                    .font(.system(size: 16, weight: .bold))
            }
        }
        .task {
            await viewModel.load()
        }
        .onDisappear {
            viewModel.pauseWorkOrder()
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

import SwiftUI

struct CompleteWorkOrderView: View {
    @StateObject private var viewModel: CompleteWorkOrderViewModel
    @ObservedObject private var navigation: TabNavigationState
    @State private var showingAddPartsSheet = false
    @State private var voiceTokens: [NSObjectProtocol] = []
    @State private var showVoiceAlert = false
    @State private var voiceAlertMessage = ""
    let dependencies: AppDependencyContainer
    let workOrderID: WorkOrder.ID

    init(workOrderID: WorkOrder.ID, dependencies: AppDependencyContainer, navigation: TabNavigationState) {
        self.workOrderID = workOrderID
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
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(Color.black)
                                    .lineLimit(2)
                                
                                Text(workOrder.description)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(Color(UIColor.secondaryLabel))
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
                                    .font(.headline)
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
                                    .font(.headline)
                                    .foregroundStyle(Color.black)
                                Spacer()
                                Button(action: { showingAddPartsSheet = true }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundStyle(AppColor.inProgress)
                                }
                                .accessibilityLabel("Add Parts")
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(Rectangle())
                            }
                            
                            // Parts List
                            ForEach(viewModel.usedParts) { part in
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack(alignment: .top) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(part.name)
                                                    .font(.body.weight(.bold))
                                                    .foregroundStyle(Color.black)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                            
                                            Spacer()
                                            
                                            // Amount & Unit Price
                                            VStack(alignment: .trailing, spacing: 4) {
                                                Text("₹\(formatDecimal(part.amount))")
                                                    .font(.body.weight(.bold))
                                                    .foregroundStyle(Color.black)
                                                
                                                Text("₹\(formatDecimal(part.unitPrice))/ea")
                                                    .font(.caption.weight(.medium))
                                                    .foregroundStyle(Color(UIColor.secondaryLabel))
                                            }
                                        }
                                        
                                        HStack {
                                            // Stepper
                                            HStack(spacing: 16) {
                                                Button(action: { viewModel.decrementPart(id: part.id) }) {
                                                    Image(systemName: "minus")
                                                        .foregroundStyle(Color(UIColor.secondaryLabel))
                                                        .font(.caption.weight(.bold))
                                                        .frame(width: 44, height: 44)
                                                }
                                                .accessibilityLabel("Decrease quantity")
                                                Text("\(part.quantity)")
                                                    .font(.subheadline.weight(.bold))
                                                Button(action: { viewModel.incrementPart(id: part.id) }) {
                                                    Image(systemName: "plus")
                                                        .foregroundStyle(Color.black)
                                                        .font(.caption.weight(.bold))
                                                        .frame(width: 44, height: 44)
                                                }
                                                .accessibilityLabel("Increase quantity")
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
                                                    .padding(14)
                                            }
                                            .accessibilityLabel("Remove part")
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
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color(UIColor.secondaryLabel))
                                Text("₹\(formatDecimal(viewModel.totalPartsCost))")
                                    .font(.headline)
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
                                .font(.headline)
                                .foregroundStyle(Color.black)
                            
                            HStack {
                                Text("₹")
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(Color(UIColor.secondaryLabel))
                                
                                Text(viewModel.laborCost.isEmpty ? "0.00" : viewModel.laborCost)
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(Color.black)
                                
                                Spacer()
                                
                                Text(formatTime(viewModel.elapsedTime))
                                    .font(.subheadline.monospaced())
                                    .foregroundStyle(Color(UIColor.secondaryLabel))
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
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color(UIColor.secondaryLabel))
                        }
                        
                        // 4. Remarks
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 4) {
                                Text("Remarks")
                                    .font(.headline)
                                    .foregroundStyle(Color.black)
                                Text("(Optional)")
                                    .font(.subheadline)
                                    .foregroundStyle(Color(UIColor.secondaryLabel))
                            }
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                TextEditor(text: $viewModel.remarks)
                                    .font(.body)
                                    .frame(height: 100)
                                    .padding(12)
                                    .scrollContentBackground(.hidden)
                                    .accessibilityLabel("Remarks")
                                
                                Text("\(viewModel.remarks.count)/250")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color(UIColor.secondaryLabel))
                                    .padding(.trailing, 12)
                                    .padding(.bottom, 12)
                                    .accessibilityLabel("\(viewModel.remarks.count) of 250 characters")
                            }
                            .background(Color(hex: 0xE8EAED))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        
                        // 5. Summary
                        VStack(spacing: 16) {
                            Text("SUMMARY")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color(UIColor.secondaryLabel))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                            HStack {
                                Text("Parts Cost")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color(UIColor.secondaryLabel))
                                Spacer()
                                Text("₹\(formatDecimal(viewModel.totalPartsCost))")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Color.black)
                            }
                            HStack {
                                Text("Labour Cost")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color(UIColor.secondaryLabel))
                                Spacer()
                                Text("₹\(formatDecimal(viewModel.totalLaborCost))")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Color.black)
                            }
                            
                            Divider().opacity(0.5)
                            
                            HStack {
                                Text("Total Cost")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(Color.black)
                                Spacer()
                                Text("₹\(formatDecimal(viewModel.totalCost))")
                                    .font(.largeTitle.weight(.black))
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
                                    .font(.headline)
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
                    .font(.headline)
            }
        }
        .task {
            await viewModel.load()
        }
        .onAppear {
            VoiceActionBridge.shared.openWorkOrderID = workOrderID

            let addPartObs = NotificationCenter.default.addObserver(forName: .voiceAddPart, object: nil, queue: .main) { [self] note in
                guard let partName = note.userInfo?["partName"] as? String else { return }
                let quantity = note.userInfo?["quantity"] as? Int ?? 1

                let candidates = viewModel.inventoryParts.filter { $0.matches(searchText: partName) }
                if candidates.count == 1, let part = candidates.first {
                    viewModel.addPart(part, quantity: quantity)
                } else if candidates.isEmpty {
                    voiceAlertMessage = "Could not find a part matching \"\(partName)\". Please add it manually from the parts sheet."
                    showVoiceAlert = true
                } else {
                    voiceAlertMessage = "Multiple parts match \"\(partName)\". Please select one from the parts sheet."
                    showVoiceAlert = true
                }
            }

            let remarkObs = NotificationCenter.default.addObserver(forName: .voiceAddRemark, object: nil, queue: .main) { [self] note in
                guard let text = note.userInfo?["text"] as? String else { return }
                let currentCount = viewModel.remarks.count
                let remaining = 250 - currentCount
                if remaining <= 0 {
                    voiceAlertMessage = "Remark is already at the 250-character limit."
                    showVoiceAlert = true
                } else if text.count > remaining {
                    viewModel.remarks += String(text.prefix(remaining))
                    voiceAlertMessage = "Remark was truncated to \(remaining) characters to fit the limit."
                    showVoiceAlert = true
                } else {
                    if viewModel.remarks.isEmpty {
                        viewModel.remarks = text
                    } else {
                        viewModel.remarks += "\n" + text
                    }
                }
            }

            voiceTokens = [addPartObs, remarkObs]
        }
        .onDisappear {
            voiceTokens.forEach { NotificationCenter.default.removeObserver($0) }
            voiceTokens.removeAll()
            VoiceActionBridge.shared.openWorkOrderID = nil
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
        .alert("Voice Action", isPresented: $showVoiceAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(voiceAlertMessage)
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

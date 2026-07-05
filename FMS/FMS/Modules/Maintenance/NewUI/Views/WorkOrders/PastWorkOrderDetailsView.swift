import SwiftUI

struct PastWorkOrderDetailsView: View {
    let workOrderID: WorkOrder.ID
    let dependencies: AppDependencyContainer
    @ObservedObject var navigation: TabNavigationState
    
    @StateObject private var viewModel: PastWorkOrderDetailsViewModel
    
    @State private var selectedPhotoUrl: String?
    @State private var isShowingPhoto = false
    
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
        .fullScreenCover(isPresented: $isShowingPhoto) {
            if let url = selectedPhotoUrl {
                PhotoViewer(photoUrl: url, isPresented: $isShowingPhoto)
            }
        }
    }
    
    private func summaryCards(for workOrder: WorkOrder) -> some View {
        VStack(spacing: 16) {
            
            // Card 1: Title & Description
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Text(workOrder.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppColor.textPrimary)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(workOrder.status == .completed ? "COMPLETED" : (workOrder.status == .fake ? "FAKE" : workOrder.status.title.uppercased()))
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(workOrder.status == .fake ? Color.red.opacity(0.15) : Color.green.opacity(0.15))
                            .foregroundStyle(workOrder.status == .fake ? Color.red : Color.green)
                            .clipShape(Capsule())
                        
                        if workOrder.isUrgent == true {
                            Text("URGENT")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.red.opacity(0.15))
                                .foregroundStyle(Color.red)
                                .clipShape(Capsule())
                        }
                    }
                }
                
                Text(workOrder.description)
                    .font(.system(size: 14))
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.2), lineWidth: 1))
            
            // Card 2: Service Details
            VStack(alignment: .leading, spacing: 16) {
                Text("Service Details")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)
                
                Divider()
                
                VStack(spacing: 12) {
                    if let vehicle = viewModel.vehicle {
                        detailRow(title: "Vehicle", value: "\(vehicle.licencePlate)\n\(vehicle.make) \(vehicle.model)")
                    } else {
                        detailRow(title: "Vehicle", value: workOrder.vehicleName)
                    }
                    
                    if let assignedBy = viewModel.assignedBy {
                        detailRow(title: "Assigned By", value: assignedBy.fullName)
                    } else {
                        detailRow(title: "Assigned By", value: "Fleet Manager")
                    }
                    
                    if let completedAt = workOrder.completedAt {
                        detailRow(title: workOrder.status == .fake ? "Reported Date" : "Completion Date", value: formatDateTime(completedAt))
                    }
                }
                
                
                let photosToShow = workOrder.status == .fake ? (workOrder.fakeReportPhotoUrls ?? workOrder.photoUrls) : workOrder.photoUrls
                
                if let photoUrls = photosToShow, !photoUrls.isEmpty {
                    Divider()
                    
                    Text(workOrder.status == .fake ? "Report Photos" : "Photos")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColor.textPrimary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(photoUrls, id: \.self) { urlString in
                                AsyncImage(url: URL(string: urlString)) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    Color.gray.opacity(0.2)
                                }
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onTapGesture {
                                    selectedPhotoUrl = urlString
                                    isShowingPhoto = true
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.2), lineWidth: 1))
            
            // Card 3: Service Summary (Only for completed)
            if workOrder.status != .fake {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Service Summary")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppColor.textPrimary)
                    
                    Divider()
                    
                    VStack(spacing: 12) {
                        detailRow(title: "Time Taken", value: viewModel.formattedLaborTime)
                        
                        if !viewModel.usedParts.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Parts Used")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.gray)
                                    Spacer()
                                }
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    ForEach(viewModel.usedParts, id: \.id) { part in
                                        Text("\(part.name) (x\(part.quantity))")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(AppColor.textPrimary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                        
                        detailRow(title: "Total Cost", value: viewModel.formattedTotalCost, valueColor: AppColor.inProgress)
                    }
                    
                    if let remarks = workOrder.remarks, !remarks.isEmpty {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Remarks")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.gray)
                            Text(remarks)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(AppColor.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.2), lineWidth: 1))
            } else {
                if let remarks = workOrder.remarks, !remarks.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Reason")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(AppColor.textPrimary)
                        
                        Divider()
                        
                        Text(remarks)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                }
            }
        }
    }
    
    private func detailRow(title: String, value: String, valueColor: Color = AppColor.textPrimary) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(Color.gray)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
        }
    }
    
    private func formatDateTime(_ isoString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = isoFormatter.date(from: isoString)
        if date == nil {
            let fallback = DateFormatter()
            fallback.dateFormat = "yyyy-MM-dd HH:mm:ss"
            date = fallback.date(from: isoString)
        }
        
        if let validDate = date {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd MMM HH:mm"
            return formatter.string(from: validDate)
        }
        return isoString
    }
}

struct PhotoViewer: View {
    let photoUrl: String
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            
            AsyncImage(url: URL(string: photoUrl)) { image in
                image
                    .resizable()
                    .scaledToFit()
            } placeholder: {
                ProgressView()
                    .tint(.white)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.white, Color.gray.opacity(0.5))
                    .padding()
            }
        }
    }
}

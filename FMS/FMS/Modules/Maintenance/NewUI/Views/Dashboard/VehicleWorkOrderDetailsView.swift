import SwiftUI
import PhotosUI

struct VehicleWorkOrderDetailsView: View {
    @StateObject private var viewModel: VehicleDetailsViewModel
    @ObservedObject private var navigation: TabNavigationState
    private let workOrderID: WorkOrder.ID
    private let dependencies: AppDependencyContainer
    
    // Report Sheet State
    @State private var isShowingReportSheet = false
    @State private var reportReason = ""
    @State private var reportPhotoData: [Data] = []
    @State private var isSubmittingReport = false
    @State private var errorMessage: String?
    @State private var showErrorAlert = false

    init(vehicleID: Vehicle.ID, workOrderID: WorkOrder.ID, dependencies: AppDependencyContainer, navigation: TabNavigationState) {
        _viewModel = StateObject(wrappedValue: VehicleDetailsViewModel(vehicleID: vehicleID, dependencies: dependencies))
        self.workOrderID = workOrderID
        self.navigation = navigation
        self.dependencies = dependencies
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                if viewModel.state.isLoading {
                    LoadingView(title: "Loading details")
                } else if let vehicle = viewModel.vehicle {
                    
                    // 1. Work Order Details Section
                    if let workOrder = viewModel.assignedWorkOrders.first(where: { $0.id == workOrderID }) {
                        workOrderDetailsSection(for: workOrder)
                    } else if let workOrder = viewModel.completedWorkOrders.first(where: { $0.id == workOrderID }) {
                        workOrderDetailsSection(for: workOrder)
                    }
                    
                    // 2. Vehicle Information
                    unifiedCard(for: vehicle)
                    
                    // 3. History of work order button
                    Button(action: {
                        navigation.push(.vehicleServiceHistory(vehicleID: vehicle.id.uuidString))
                    }) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("History of Vehicle")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .foregroundStyle(Color.blue)
                        .background(Color.blue.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    
                    // 4. Start Button
                    let workOrder = viewModel.assignedWorkOrders.first(where: { $0.id == workOrderID }) ?? viewModel.completedWorkOrders.first(where: { $0.id == workOrderID })
                    let isInProgress = workOrder?.status == .inProgress
                    let buttonTitle = isInProgress ? "Continue Work Order" : "Start Work Order"
                    let buttonColor = isInProgress ? Color.orange : Color.green
                    
                    Button(action: {
                        navigation.push(.completeWorkOrder(workOrderID: workOrderID))
                    }) {
                        Text(buttonTitle)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(buttonColor)
                            .clipShape(Capsule())
                            .shadow(color: buttonColor.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .disabled(workOrder?.status == .completed)
                    .padding(.top, 8)
                    
                } else {
                    MPEmptyStateView(title: "Details Unavailable", message: "This information could not be loaded.", systemImage: AppIcon.vehicle)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, AppSpacing.large)
            .padding(.bottom, AppSpacing.xLarge)
        }
        .background(AppColor.background.ignoresSafeArea())
        .navigationTitle("Work Order Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    isShowingReportSheet = true
                }) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.red)
                }
            }
        }
        .sheet(isPresented: $isShowingReportSheet) {
            ReportWorkOrderSheet(
                reason: $reportReason,
                photoData: $reportPhotoData,
                isSubmitting: $isSubmittingReport,
                onSubmit: {
                    Task {
                        isSubmittingReport = true
                        do {
                            try await viewModel.submitReport(workOrderID: workOrderID, reason: reportReason, photos: reportPhotoData)
                            await MainActor.run {
                                isSubmittingReport = false
                                isShowingReportSheet = false
                                reportReason = ""
                                reportPhotoData = []
                                navigation.popToRoot()
                            }
                        } catch {
                            await MainActor.run {
                                isSubmittingReport = false
                                errorMessage = error.localizedDescription
                                showErrorAlert = true
                            }
                        }
                    }
                }
            )
            .alert("Report Failed", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred.")
            }
        }
        .onAppear {
            Task {
                await viewModel.load()
            }
        }
    }

    private func workOrderDetailsSection(for workOrder: WorkOrder) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            
            HStack(alignment: .top) {
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
                
                Spacer()
                
                if workOrder.isUrgent == true {
                    Text("URGENT")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            
            Divider().opacity(0.5)
            
            HStack(spacing: 24) {
                // Scheduled Block
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.blue)
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatDate(workOrder.dueDate))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.black)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                        Text("Scheduled")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.gray)
                    }
                }
                
                // Assigned Block
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.orange)
                        .padding(8)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        if let fname = workOrder.scheduledByRelation?.users?.f_name {
                            Text("\(fname) \(workOrder.scheduledByRelation?.users?.l_name ?? "")")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.black)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        } else if let scheduledBy = workOrder.scheduledBy {
                            Text("ID \(scheduledBy.uuidString.prefix(6))")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.black)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        } else {
                            Text("Fleet Manager")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.black)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        
                        Text(workOrder.taskTitle?.hasPrefix("Routine Maintenance -") == true ? "Auto assigned by Manager" : "Assigned")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.gray)
                    }
                }
                
                Spacer()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy"
        return formatter.string(from: date)
    }

    private func unifiedCard(for vehicle: Vehicle) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Image(vehicle.assetImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(vehicle.name)
                        .font(AppTypography.title)
                        .foregroundStyle(AppColor.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        
                    Text(vehicle.licencePlate)
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColor.textSecondary)
                }
                Spacer()
            }
            .padding(12)
            
            Divider()
            
            let columns = [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ]
            
            LazyVGrid(columns: columns, spacing: 12) {
                horizontalDetailItem(icon: "car.fill", title: "Type", value: vehicle.vehicleType.capitalized)
                horizontalDetailItem(icon: "fuelpump.fill", title: "Fuel", value: vehicle.fuelType?.capitalized ?? "Unknown")
                horizontalDetailItem(icon: "calendar", title: "Year", value: String(vehicle.year))
                horizontalDetailItem(icon: "123.rectangle", title: "Licence", value: vehicle.licencePlate)
            }
            .padding(12)
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
                RoundedRectangle(cornerRadius: 6)
                    .fill(AppColor.brand.opacity(0.1))
                    .frame(width: 28, height: 28)
                
                Image(systemName: icon)
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColor.brand)
            }
            
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(AppTypography.callout.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(title)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColor.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Report Sheet View
struct ReportWorkOrderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var reason: String
    @Binding var photoData: [Data]
    @Binding var isSubmitting: Bool
    let onSubmit: () -> Void
    
    @State private var showingCameraPicker = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Reason TextEditor
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reason for Report")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.gray)
                        
                        TextEditor(text: $reason)
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .frame(height: 120)
                            .padding(8)
                            .background(Color.gray)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        
                        if reason.isEmpty {
                            Text("e.g., Vehicle is fine, no issue found")
                                .font(.system(size: 14, weight: .regular, design: .rounded))
                                .foregroundStyle(Color.gray.opacity(0.7))
                                .padding(.top, -110)
                                .padding(.leading, 12)
                                .allowsHitTesting(false)
                        }
                    }
                    
                    // Photo Attachment
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Attachments (Optional)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.gray)
                        
                        if !photoData.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(photoData.indices, id: \.self) { index in
                                        if let uiImage = UIImage(data: photoData[index]) {
                                            ZStack(alignment: .topTrailing) {
                                                Image(uiImage: uiImage)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 120, height: 120)
                                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                                
                                                Button(action: {
                                                    photoData.remove(at: index)
                                                }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.title2)
                                                        .foregroundStyle(Color.white, Color.red)
                                                        .padding(6)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        Button(action: { showingCameraPicker = true }) {
                            HStack {
                                Image(systemName: "camera.fill")
                                Text(photoData.isEmpty ? "Take Photo Proof" : "Take More Photos")
                            }
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
                            )
                        }
                        .sheet(isPresented: $showingCameraPicker) {
                            MaintenanceCameraPicker(selectedImage: Binding(
                                get: { nil },
                                set: { newImage in
                                    if let image = newImage, let data = image.jpegData(compressionQuality: 0.8) {
                                        self.photoData.append(data)
                                    }
                                }
                            ))
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Report Work Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Button("Done") {
                            onSubmit()
                        }
                        .font(.system(size: 16, weight: .bold))
                        .disabled(reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .interactiveDismissDisabled(isSubmitting)
    }
}

// MARK: - Maintenance Camera Picker (Strictly Camera Only)
struct MaintenanceCameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedImage: UIImage?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: MaintenanceCameraPicker

        init(_ parent: MaintenanceCameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

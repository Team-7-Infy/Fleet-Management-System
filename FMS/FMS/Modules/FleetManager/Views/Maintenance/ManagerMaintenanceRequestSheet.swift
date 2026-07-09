//
//  ManagerMaintenanceRequestSheet.swift
//  FMS
//
//  Created by Veer on 26/06/26.
//


import SwiftUI
import PhotosUI
import Supabase

struct ManagerMaintenanceRequestSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MaintenanceViewModel
    @ObservedObject var vehiclesViewModel: VehicleViewModel
    @ObservedObject var usersViewModel: UserManagementViewModel
    @ObservedObject var tripsViewModel: TripManagementViewModel
    @State private var form = FleetManagerMaintenanceTaskForm()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    var initialVehicleId: UUID?
    var currentUserId: UUID?
    let services: AppServices

    private static let vehicleTypeOptions = ["All Types", "Car", "Van", "Truck", "Bus"]
    @State private var selectedVehicleType: String = "All Types"

    private static let categoryOptions = [
        "Tires & Pressure", "Brakes & Fluid", "Headlights & Tail Lights",
        "Engine Oil & Coolant", "Mirrors & Windshield", "Wipers & Washer Fluid", "Other"
    ]
    @State private var selectedCategory: String = ""
    @State private var isSubmitting = false

    private var hasRegisteredPersonnel: Bool {
        !usersViewModel.maintenancePersonnel.isEmpty
    }

    private var availableVehicles: [Vehicle] {
        var list = vehiclesViewModel.vehicles.filter { $0.status == .available }
        if selectedVehicleType != "All Types" {
            list = list.filter { $0.vehicleType.localizedCaseInsensitiveCompare(selectedVehicleType) == .orderedSame }
        }
        list = list.filter { vehicle in
            let isAssignedToActiveTrip = tripsViewModel.activeTrips.contains { $0.vehicleId == vehicle.id }
            return !isAssignedToActiveTrip
        }
        return list
    }

    private var availablePersonnel: [MaintenancePersonnel] {
        usersViewModel.maintenancePersonnel.filter { person in
            person.status == .available
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if vehiclesViewModel.vehicles.isEmpty || hasRegisteredPersonnel == false {
                    GlassPanel {
                        EmptyStateView(
                            title: "Maintenance setup needs data",
                            message: "Add a vehicle and register at least one maintenance person before assigning work orders.",
                            systemImage: "wrench.and.screwdriver"
                        )
                    }
                } else {
                    Picker("Vehicle Type", selection: $selectedVehicleType) {
                        ForEach(Self.vehicleTypeOptions, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .fleetField()

                    Picker("Vehicle", selection: $form.vehicleId) {
                        Text("Select vehicle").tag(Optional<UUID>.none)
                        ForEach(availableVehicles) { vehicle in
                            Text(vehicle.licencePlate).tag(Optional(vehicle.id))
                        }
                    }
                    .fleetField()

                    Picker("Category", selection: $selectedCategory) {
                        Text("Select category").tag("")
                        ForEach(Self.categoryOptions, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                    .fleetField()

                    TextField("Title", text: $form.title)
                        .fleetField()
                        .disabled(selectedCategory != "Other" && !selectedCategory.isEmpty)

                    TextField("Description", text: $form.description, axis: .vertical)
                        .lineLimit(2...4)
                        .fleetField()

                    DatePicker("Scheduled date", selection: $form.scheduledDate, in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date)
                        .fleetField()

                    Toggle("Urgent", isOn: $form.isUrgent)
                        .fleetField()

                    Toggle("Auto Assign", isOn: $form.isAutoAssign)
                        .fleetField()

                    if !form.isAutoAssign {
                        Picker("Assign To", selection: $form.executedBy) {
                            Text("Unassigned").tag(Optional<UUID>.none)
                            ForEach(availablePersonnel) { person in
                                let user = usersViewModel.user(for: person.userId)
                                Text(user?.displayName ?? person.id.uuidString)
                                    .tag(Optional(person.id))
                            }
                        }
                        .fleetField()
                    }

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        HStack {
                            Image(systemName: selectedPhotoData == nil ? "photo.badge.plus" : "checkmark.circle.fill")
                            Text(selectedPhotoData == nil ? "Attach Photo" : "Photo Attached")
                            Spacer()
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(selectedPhotoData == nil ? .blue : .green)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .onChange(of: selectedPhotoItem) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                selectedPhotoData = data
                            }
                        }
                    }

                    FeedbackView(success: viewModel.successMessage, error: viewModel.errorMessage)

                    Button {
                        guard !isSubmitting else { return }
                        isSubmitting = true
                        Task {
                            defer { isSubmitting = false }

                            if let photoData = selectedPhotoData {
                                do {
                                    let url = try await uploadWorkOrderPhoto(photoData)
                                    form.photoUrl = url
                                } catch {
                                    viewModel.errorMessage = "Failed to upload photo: \(error.localizedDescription)"
                                    return
                                }
                            }

                            if form.executedBy != nil && form.status == .scheduled {
                                form.status = .assigned
                            }

                            if await viewModel.createTask(form: form) {
                                await vehiclesViewModel.load()
                                dismiss()
                            }
                        }
                    } label: {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            }
                            Label("Assign Maintenance", systemImage: "wrench.and.screwdriver")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(FleetPalette.accent)
                    .disabled(form.isValid == false || form.vehicleId == nil || isSubmitting)
                }
            }
            .padding()
        }
        .fleetScreenBackground()
        .navigationTitle("Request Maintenance")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedVehicleType) { _, _ in
            if let currentId = form.vehicleId,
               !availableVehicles.contains(where: { $0.id == currentId }) {
                form.vehicleId = nil
            }
        }
        .onChange(of: selectedCategory) { _, newValue in
            if newValue != "Other" && !newValue.isEmpty {
                form.title = newValue
            }
        }
        .onAppear {
            form.vehicleId = form.vehicleId ?? initialVehicleId ?? availableVehicles.first?.id
            form.scheduledBy = form.scheduledBy ?? currentUserId.flatMap(usersViewModel.managerId(for:))

            Task {
                if let leastLoadedId = await viewModel.getNextLeastLoadedAssigneeId() {
                    form.executedBy = form.executedBy ?? leastLoadedId
                }
            }
        }
    }

    private func uploadWorkOrderPhoto(_ imageData: Data) async throws -> String {
        guard let image = UIImage(data: imageData),
              let uploadData = image.jpegData(compressionQuality: 0.82) else {
            throw URLError(.cannotDecodeContentData)
        }
        let bucketId = "maintenance"
        let path = "workorder-\(UUID().uuidString)-\(Int(Date().timeIntervalSince1970)).jpg"

        let publicURL = try services.supabase.client.storage
            .from(bucketId)
            .getPublicURL(path: path)
            .absoluteString

        let baseURL = EnvironmentConfig.supabaseURL
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        components.path = "/storage/v1/object/\(bucketId)/\(path)"
        guard let uploadURL = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.setValue("3600", forHTTPHeaderField: "cache-control")
        request.setValue("true", forHTTPHeaderField: "x-upsert")
        request.setValue(EnvironmentConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        if let token = try? await services.supabase.client.auth.session.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = uploadData

        let (_, urlResponse) = try await URLSession.shared.data(for: request)
        guard let httpResponse = urlResponse as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return publicURL
    }
}
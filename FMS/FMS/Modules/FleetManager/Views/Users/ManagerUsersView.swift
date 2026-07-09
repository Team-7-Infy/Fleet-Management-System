import SwiftUI

enum ManagerUserSegment: String, CaseIterable, Identifiable {
    case drivers
    case mechanics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .drivers:
            return "Drivers"
        case .mechanics:
            return "Mechanics"
        }
    }

    var emptyTitle: String {
        switch self {
        case .drivers:
            return "No drivers yet"
        case .mechanics:
            return "No mechanics yet"
        }
    }
}

struct ManagerUsersView: View {
    @ObservedObject var viewModel: UserManagementViewModel
    @ObservedObject var tripsViewModel: TripManagementViewModel
    @ObservedObject var maintenanceViewModel: MaintenanceViewModel
    @Binding var selectedSegment: ManagerUserSegment
    @State private var searchText = ""
    @State private var selectedStatusFilter = "All"

    var openAddUser: () -> Void

    private var baseUsers: [User] {
        switch selectedSegment {
        case .drivers:
            return viewModel.driverUsers
        case .mechanics:
            return viewModel.maintenanceUsers
        }
    }

    private var availableStatusFilters: [String] {
        switch selectedSegment {
        case .drivers:
            return ["Available", "On Trip", "Scheduled", "Unavailable"]
        case .mechanics:
            return ["Available", "In Progress", "Unavailable"]
        }
    }

    private var users: [User] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filteredByStatus = baseUsers.filter { user in
            guard selectedStatusFilter != "All" else { return true }
            let status = calculateStatusInfo(for: user).text
            return status.lowercased() == selectedStatusFilter.lowercased()
        }
        guard query.isEmpty == false else { return filteredByStatus }
        return filteredByStatus.filter { matchesSearch($0, query: query) }
    }

    private func calculateStatusInfo(for user: User) -> (text: String, color: Color) {
        calculateUserStatus(
            user: user,
            unavailableUserIds: viewModel.unavailableUserIds,
            drivers: viewModel.drivers,
            maintenancePersonnel: viewModel.maintenancePersonnel,
            trips: tripsViewModel.trips,
            tasks: maintenanceViewModel.tasks
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            FeedbackView(success: nil, error: viewModel.errorMessage)

            if baseUsers.isEmpty {
                ContentUnavailableView(
                    selectedSegment.emptyTitle,
                    systemImage: "person.2.slash",
                    description: Text("Use Add User to create role profiles for assignment.")
                )
            } else if users.isEmpty {
                ContentUnavailableView.search
            } else {
                List {
                    ForEach(users) { user in
                        NavigationLink {
                            ManagerUserDetailView(
                                user: user,
                                viewModel: viewModel,
                                tripsViewModel: tripsViewModel,
                                maintenanceViewModel: maintenanceViewModel
                            )
                        } label: {
                            ManagerUserCard(
                                user: user,
                                viewModel: viewModel,
                                tripsViewModel: tripsViewModel,
                                maintenanceViewModel: maintenanceViewModel
                            )
                        }
                        .listRowBackground(FleetPalette.surface)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task { _ = await viewModel.deleteUser(user) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button {
                                viewModel.toggleUserUnavailable(userId: user.id)
                            } label: {
                                if viewModel.unavailableUserIds.contains(user.id) {
                                    Label("Mark Available", systemImage: "checkmark.circle")
                                } else {
                                    Label("Mark Unavailable", systemImage: "minus.circle")
                                }
                            }

                            Button(role: .destructive) {
                                Task { _ = await viewModel.deleteUser(user) }
                            } label: {
                                Label("Delete User", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(FleetPalette.background)
                .listRowSeparatorTint(Color.gray)
                .tint(FleetPalette.textPrimary)
            }
        }
        .fleetScreenBackground()
        .navigationTitle(selectedSegment.title)
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search users")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button {
                        selectedStatusFilter = "All"
                    } label: {
                        HStack {
                            Text("All")
                            if selectedStatusFilter == "All" {
                                Image(systemName: "checkmark")
                            }
                        }
                    }

                    ForEach(availableStatusFilters, id: \.self) { status in
                        Button {
                            selectedStatusFilter = status
                        } label: {
                            HStack {
                                Text(status)
                                if selectedStatusFilter == status {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                }
                .accessibilityLabel("Filter by status")
                .tint(FleetPalette.textPrimary)
            }
            ToolbarItem(placement: .principal) {
                Picker("User Type", selection: $selectedSegment) {
                    ForEach(ManagerUserSegment.allCases) { segment in
                        Text(segment.title).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add User", systemImage: "plus", action: openAddUser)
                    .tint(FleetPalette.textPrimary)
            }
        }
        .onChange(of: selectedSegment) { _, _ in
            selectedStatusFilter = "All"
        }
        .refreshable {
            await tripsViewModel.load()
            await maintenanceViewModel.load()
            await viewModel.load(
                trips: tripsViewModel.trips,
                tasks: maintenanceViewModel.tasks
            )
        }
    }

    private func driverProfile(for user: User) -> Driver? {
        viewModel.drivers.first { $0.userId == user.id }
    }

    private func maintenanceProfile(for user: User) -> MaintenancePersonnel? {
        viewModel.maintenancePersonnel.first { $0.userId == user.id }
    }

    private func isDriverOnTrip(_ user: User) -> Bool {
        guard let driver = driverProfile(for: user) else { return false }
        return tripsViewModel.trips.contains { $0.driverId == driver.id && $0.status == .accepted }
    }

    private func isDriverAssigned(_ user: User) -> Bool {
        guard let driver = driverProfile(for: user) else { return false }
        return tripsViewModel.trips.contains { $0.driverId == driver.id && ($0.status == .scheduled || $0.status == .pending || $0.status == .accepted) }
    }

    private func hasActiveWork(_ user: User) -> Bool {
        guard let personnel = maintenanceProfile(for: user) else { return false }
        return maintenanceViewModel.openTasks.contains { $0.executedBy == personnel.id }
    }

    private func matchesSearch(_ user: User, query: String) -> Bool {
        let searchable = [
            user.displayName,
            user.shortUID
        ]
        return searchable.contains {
            $0.localizedCaseInsensitiveContains(query)
        }
    }
}

private struct ManagerUserCard: View {
    var user: User
    @ObservedObject var viewModel: UserManagementViewModel
    @ObservedObject var tripsViewModel: TripManagementViewModel
    @ObservedObject var maintenanceViewModel: MaintenanceViewModel

    var body: some View {
        HStack(spacing: 14) {
            AvatarView(name: user.displayName, role: user.role, size: 48, imageURL: user.avatarImageURL)

            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(FleetPalette.textPrimary)
                    .lineLimit(1)

                Text("UID \(user.shortUID)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(FleetPalette.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityLabel("\(user.displayName), \(user.role.title)")
    }
}

struct ManagerUserDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State var user: User
    @ObservedObject var viewModel: UserManagementViewModel
    @ObservedObject var tripsViewModel: TripManagementViewModel
    @ObservedObject var maintenanceViewModel: MaintenanceViewModel
    @State private var showEditSheet = false
    @State private var showDeleteConfirm = false
    @State private var editForm = FleetManagerUserForm()

    private var driverProfile: Driver? {
        viewModel.drivers.first { $0.userId == user.id }
    }

    private var maintenanceProfile: MaintenancePersonnel? {
        viewModel.maintenancePersonnel.first { $0.userId == user.id }
    }

    private var driverTrips: [Trip] {
        guard let driverProfile else { return [] }
        return tripsViewModel.trips.filter { $0.driverId == driverProfile.id }
    }

    private var workOrders: [MaintenanceTask] {
        guard let maintenanceProfile else { return [] }
        return maintenanceViewModel.tasks.filter { $0.executedBy == maintenanceProfile.id }
    }


    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                userHeroSection

                switch user.role {
                case .driver:
                    driverInfoCard
                    driverScoreCard
                    driverTripHistorySection
                case .maintenancePersonnel:
                    maintenanceInfoCard
                    maintenanceTasksHistorySection
                case .fleetManager:
                    managerInfoCard
                }

                Button {
                    editForm = FleetManagerUserForm(
                        name: user.displayName,
                        firstName: user.fName,
                        lastName: user.lName,
                        email: user.email,
                        aadhar: user.aadhar,
                        contact: "\(user.contact)",
                        address: user.address,
                        avatarUrl: user.avatarUrl ?? "",
                        role: user.role,
                        licenceNumber: driverProfile?.licenceNum ?? "",
                        vehicleType: driverProfile?.vehicleType ?? "van"
                    )
                    showEditSheet = true
                } label: {
                    Label("Edit Profile Details", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label(user.isActive ? "Deactivate Account" : "Activate Account", systemImage: user.isActive ? "person.crop.circle.badge.xmark" : "person.crop.circle.badge.checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .padding()
        }
        .fleetScreenBackground()
        .navigationTitle(user.role == .driver ? "Driver Details" : "User Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEditSheet) {
            NavigationStack {
                ManagerUserEditView(user: $user, viewModel: viewModel, form: $editForm)
            }
        }
        .alert("Delete \(user.displayName)?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    if await viewModel.deleteUser(user) {
                        dismiss()
                    }
                }
            }
        } message: {
            Text("The user will be deactivated. Their data is preserved and can be restored later if needed.")
        }
    }

    private var userHeroSection: some View {
        VStack(spacing: 10) {
            AvatarView(name: user.displayName, role: user.role, size: 86, imageURL: user.avatarImageURL)

            VStack(spacing: 4) {
                Text(user.displayName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(FleetPalette.textPrimary)

                Text(user.email)
                    .font(.subheadline)
                    .foregroundStyle(FleetPalette.textSecondary)

                HStack(spacing: 8) {
                    Text("UID \(user.shortUID)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(FleetPalette.textSecondary)

                    Text(user.role.title.uppercased())
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(FleetPalette.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(FleetPalette.accent.opacity(0.12))
                        .clipShape(Capsule())

                    StatusPill(
                        text: user.isActive ? "Active" : "Inactive",
                        color: user.isActive ? FleetPalette.success : FleetPalette.neutral,
                        dotSize: 8
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private var driverInfoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            DashboardSectionTitle("Driver Info")

            GlassPanel(hasBorder: false) {
                if let driverProfile {
                    VStack(spacing: 12) {
                        InfoRow(title: "License", value: driverProfile.licenceNum.isEmpty ? "Not available" : driverProfile.licenceNum)
                        Divider()
                        InfoRow(title: "Vehicle Type", value: driverProfile.vehicleType.isEmpty ? "Not available" : driverProfile.vehicleType.capitalized)
                        Divider()
                        HStack {
                            Text("Status")
                                .font(.subheadline)
                                .foregroundStyle(FleetPalette.textSecondary)
                                .frame(width: 112, alignment: .leading)

                            Spacer()

                            StatusPill(
                                text: driverProfile.status.title,
                                color: FleetPalette.personnelStatus(driverProfile.status),
                                dotSize: 8
                            )
                        }
                        Divider()
                        InfoRow(title: "Phone", value: "\(user.contact)")
                        Divider()
                        InfoRow(title: "Aadhar", value: user.aadhar.isEmpty ? "Not provided" : user.aadhar)
                        Divider()
                        InfoRow(title: "Address", value: user.address.isEmpty ? "Not provided" : user.address)
                    }
                } else {
                    EmptyStateView(
                        title: "Profile pending",
                        message: "This driver user exists but the driver profile record could not be found.",
                        systemImage: "person.text.rectangle"
                    )
                }
            }
        }
    }

    private var driverTripHistorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            DashboardSectionTitle("Trip History")

            GlassPanel(hasBorder: false) {
                let completedTrips = driverTrips.filter { $0.status == .completed }
                if completedTrips.isEmpty {
                    EmptyStateView(
                        title: "No completed trips",
                        message: "Completed assignments will appear here.",
                        systemImage: "checkmark.circle"
                    )
                } else {
                    VStack(spacing: 12) {
                        ForEach(completedTrips) { trip in
                            VStack(alignment: .leading, spacing: 5) {
                                Text("\(trip.startLocation) to \(trip.endLocation)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(FleetPalette.textPrimary)

                                if let endTime = trip.endTime {
                                    Text("Completed \(endTime, style: .date)")
                                        .font(.caption)
                                        .foregroundStyle(FleetPalette.textSecondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            if trip.id != completedTrips.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    private var driverScoreCard: some View {
        guard let driverProfile else { return AnyView(EmptyView()) }
        let score = viewModel.driverScore(for: driverProfile.id)

        return AnyView(VStack(alignment: .leading, spacing: 10) {
            DashboardSectionTitle("Driver Safety Score")

            GlassPanel(hasBorder: false) {
                if let score {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Overall Score")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(Int(score.overallScore))")
                                .font(.title.weight(.heavy))
                                .foregroundStyle(score.overallScore >= 70 ? .green : score.overallScore >= 40 ? .orange : .red)
                        }
                        Divider()
                        if let ins = score.inspectionFalseRate {
                            InfoRow(title: "Inspection Compliance", value: "\(Int(ins))%")
                        }
                        if let geo = score.geofenceViolationRate {
                            InfoRow(title: "Route Adherence", value: "\(Int(geo))%")
                        }
                        if let comp = score.complianceViolationRate {
                            InfoRow(title: "Schedule Adherence", value: "\(Int(comp))%")
                        }
                        if let mile = score.mileageAccuracy {
                            InfoRow(title: "Mileage Accuracy", value: "\(Int(mile))%")
                        }
                        InfoRow(title: "Last Calculated", value: score.calculatedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                } else {
                    EmptyStateView(
                        title: "Score Not Calculated Yet",
                        message: "The driver safety score will be available after the first completed trip.",
                        systemImage: "chart.bar.xaxis"
                    )
                }
            }
        })
    }

    private var maintenanceInfoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            DashboardSectionTitle("Personnel Info")

            GlassPanel(hasBorder: false) {
                if let maintenanceProfile {
                    VStack(spacing: 12) {
                        InfoRow(title: "Status", value: maintenanceProfile.status.title)
                        Divider()
                        InfoRow(title: "Phone", value: "\(user.contact)")
                        Divider()
                        InfoRow(title: "Aadhar", value: user.aadhar.isEmpty ? "Not provided" : user.aadhar)
                        Divider()
                        InfoRow(title: "Address", value: user.address.isEmpty ? "Not provided" : user.address)
                    }
                } else {
                    EmptyStateView(
                        title: "Profile pending",
                        message: "This maintenance user exists but the personnel record could not be found.",
                        systemImage: "person.text.rectangle"
                    )
                }
            }
        }
    }

    private var maintenanceTasksHistorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            DashboardSectionTitle("Work History")

            GlassPanel(hasBorder: false) {
                if workOrders.isEmpty {
                    EmptyStateView(
                        title: "No tasks assigned",
                        message: "Assigned maintenance tasks will appear here.",
                        systemImage: "wrench.and.screwdriver"
                    )
                } else {
                    VStack(spacing: 12) {
                        ForEach(workOrders) { task in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(task.title ?? "Maintenance Task")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(FleetPalette.textPrimary)

                                HStack {
                                    StatusPill(
                                        text: task.status.title,
                                        color: FleetPalette.maintenanceStatus(task.status),
                                        dotSize: 8
                                    )

                                    Spacer()

                                    Text("Scheduled \(task.scheduledDate.date, style: .date)")
                                        .font(.caption)
                                        .foregroundStyle(FleetPalette.textSecondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            if task.id != workOrders.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    private var managerInfoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            DashboardSectionTitle("Manager Info")

            GlassPanel(hasBorder: false) {
                VStack(spacing: 12) {
                    InfoRow(title: "Phone", value: "\(user.contact)")
                    Divider()
                    InfoRow(title: "Aadhar", value: user.aadhar.isEmpty ? "Not provided" : user.aadhar)
                    Divider()
                    InfoRow(title: "Address", value: user.address.isEmpty ? "Not provided" : user.address)
                }
            }
        }
    }
}

private struct ManagerUserEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var user: User
    @ObservedObject var viewModel: UserManagementViewModel
    @Binding var form: FleetManagerUserForm

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TextField("Name", text: $form.name)
                    .textContentType(.name)
                    .fleetField()
                FleetFieldValidationMessage(message: visibleValidationMessage(for: .name))

                TextField("Email / Login ID", text: $form.email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .fleetField()
                FleetFieldValidationMessage(message: visibleValidationMessage(for: .email))

                TextField("Aadhar", text: $form.aadhar)
                    .keyboardType(.numberPad)
                    .fleetField()
                FleetFieldValidationMessage(message: visibleValidationMessage(for: .aadhaar))

                TextField("Contact", text: $form.contact)
                    .keyboardType(.phonePad)
                    .fleetField()
                FleetFieldValidationMessage(message: visibleValidationMessage(for: .contact))

                TextField("Address", text: $form.address, axis: .vertical)
                    .lineLimit(2...4)
                    .fleetField()
                FleetFieldValidationMessage(message: visibleValidationMessage(for: .address))

                TextField("Photo / DP URL", text: $form.avatarUrl)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .fleetField()
                FleetFieldValidationMessage(message: visibleValidationMessage(for: .avatarURL))

                if user.role == .driver {
                    TextField("Licence number", text: $form.licenceNumber)
                        .textInputAutocapitalization(.characters)
                        .fleetField()
                    FleetFieldValidationMessage(message: visibleValidationMessage(for: .licenceNumber))

                    Picker("Vehicle Type", selection: $form.vehicleType) {
                        ForEach(["car", "van", "bus", "truck"], id: \.self) { type in
                            Text(type.capitalized).tag(type)
                        }
                    }
                    .fleetField()
                }

                FeedbackView(success: viewModel.successMessage, error: viewModel.errorMessage)

                Button {
                    Task {
                        if let issue = form.validationIssues.first {
                            viewModel.errorMessage = issue.message
                            viewModel.successMessage = nil
                            return
                        }

                        var updated = user
                        let nameParts = form.normalizedNameParts
                        updated.fName = nameParts.first
                        updated.lName = nameParts.last
                        updated.email = form.normalizedEmail
                        updated.aadhar = form.normalizedAadhaar
                        updated.address = form.normalizedAddress
                        updated.avatarUrl = form.normalizedAvatarUrl
                        if let contact = form.contactValue {
                            updated.contact = contact
                        }
                        let userSaved = await viewModel.updateUser(updated)
                        let driverSaved = user.role == .driver
                            ? await viewModel.updateDriverProfile(
                                userId: user.id,
                                licenceNumber: form.normalizedLicenceNumber,
                                vehicleType: form.vehicleType
                            )
                            : true
                        if userSaved && driverSaved {
                            user = updated
                            dismiss()
                        }
                    }
                } label: {
                    Label("Save Changes", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(FleetPalette.accent)
                .disabled(form.isValid == false)
            }
            .padding()
        }
        .fleetScreenBackground()
        .navigationTitle("Edit User")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .onChange(of: form.aadhar) { _, newValue in
            form.aadhar = String(UserProfileValidation.normalizedAadhaar(newValue).prefix(12))
        }
        .onChange(of: form.contact) { _, newValue in
            form.contact = String(UserProfileValidation.normalizedContact(newValue).prefix(10))
        }
        .onChange(of: form.licenceNumber) { _, newValue in
            form.licenceNumber = UserProfileValidation.normalizedLicenceNumber(newValue)
        }
    }

    private func visibleValidationMessage(for field: UserProfileValidationField) -> String? {
        switch field {
        case .name where form.normalizedName.isEmpty:
            return nil
        case .email where form.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty:
            return nil
        case .aadhaar where form.normalizedAadhaar.isEmpty:
            return nil
        case .contact where form.normalizedContact.isEmpty:
            return nil
        case .address where form.normalizedAddress.isEmpty:
            return nil
        case .avatarURL where form.avatarUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty:
            return nil
        case .licenceNumber where form.normalizedLicenceNumber.isEmpty:
            return nil
        default:
            return form.validationMessage(for: field)
        }
    }
}

// MARK: - Status Calculation Helper
func calculateUserStatus(
    user: User,
    unavailableUserIds: Set<UUID>,
    drivers: [Driver],
    maintenancePersonnel: [MaintenancePersonnel],
    trips: [Trip],
    tasks: [MaintenanceTask]
) -> (text: String, color: Color) {
    if unavailableUserIds.contains(user.id) {
        return ("Unavailable", FleetPalette.neutral)
    }

    switch user.role {
    case .driver:
        guard let driver = drivers.first(where: { $0.userId == user.id }) else {
            return (user.isActive ? "Active" : "Inactive", user.isActive ? FleetPalette.success : FleetPalette.neutral)
        }

        // Check if they are On Trip
        let driverTrips = trips.filter { $0.driverId == driver.id }
        let hasActiveTrip = driverTrips.contains { $0.status == .accepted || $0.status == .inProgress }
        if hasActiveTrip {
            return ("On Trip", FleetPalette.accent)
        }

        // Check if they are Scheduled
        let hasScheduledTrip = driverTrips.contains { $0.status == .scheduled || $0.status == .pending || $0.status == .rejectionPending }
        if hasScheduledTrip {
            return ("Scheduled", FleetPalette.warning)
        }

        return ("Available", FleetPalette.success)

    case .maintenancePersonnel:
        guard let personnel = maintenancePersonnel.first(where: { $0.userId == user.id }) else {
            return (user.isActive ? "Active" : "Inactive", user.isActive ? FleetPalette.success : FleetPalette.neutral)
        }

        // Check if they are In Progress
        let hasActiveWork = tasks.contains { $0.executedBy == personnel.id && $0.status == .inProgress }
        if hasActiveWork {
            return ("In Progress", FleetPalette.warning)
        }

        return ("Available", FleetPalette.success)

    case .fleetManager:
        return (user.isActive ? "Active" : "Inactive", user.isActive ? FleetPalette.success : FleetPalette.neutral)
    }
}

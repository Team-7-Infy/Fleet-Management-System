import SwiftUI

enum ManagerUserSegment: String, CaseIterable, Identifiable {
    case drivers
    case maintenance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .drivers:
            return "Drivers"
        case .maintenance:
            return "Maintenance"
        }
    }

    var emptyTitle: String {
        switch self {
        case .drivers:
            return "No drivers yet"
        case .maintenance:
            return "No maintenance personnel yet"
        }
    }
}

private struct ManagerUserGroup: Identifiable {
    var id: String { title }
    var title: String
    var users: [User]
}

struct ManagerUsersView: View {
    @ObservedObject var viewModel: UserManagementViewModel
    @ObservedObject var tripsViewModel: TripManagementViewModel
    @ObservedObject var maintenanceViewModel: MaintenanceViewModel
    @Binding var selectedSegment: ManagerUserSegment
    @State private var searchText = ""

    var openAddUser: () -> Void

    private var baseUsers: [User] {
        switch selectedSegment {
        case .drivers:
            return viewModel.driverUsers
        case .maintenance:
            return viewModel.maintenanceUsers
        }
    }

    private var users: [User] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else { return baseUsers }
        return baseUsers.filter { matchesSearch($0, query: query) }
    }

    private var groupedUsers: [ManagerUserGroup] {
        switch selectedSegment {
        case .drivers:
            return makeGroups([
                ("On Trip", { isDriverOnTrip($0) }),
                ("Assigned", { isDriverAssigned($0) && isDriverOnTrip($0) == false }),
                ("Registered", { isDriverOnTrip($0) == false && isDriverAssigned($0) == false })
            ])
        case .maintenance:
            return makeGroups([
                ("Assigned Work", { hasActiveWork($0) }),
                ("Registered", { hasActiveWork($0) == false })
            ])
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("User Type", selection: $selectedSegment) {
                ForEach(ManagerUserSegment.allCases) { segment in
                    Text(segment.title).tag(segment)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    FeedbackView(success: viewModel.successMessage, error: viewModel.errorMessage)
                    userList
                }
                .padding()
            }
        }
        .fleetScreenBackground()
        .navigationTitle("Users")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search users")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add User", systemImage: "plus", action: openAddUser)
            }
        }
        .refreshable {
            await viewModel.load()
            await tripsViewModel.load()
            await maintenanceViewModel.load()
        }
    }

    private var userList: some View {
        VStack(spacing: 14) {
            if baseUsers.isEmpty {
                ContentUnavailableView(
                    selectedSegment.emptyTitle,
                    systemImage: "person.2.slash",
                    description: Text("Use Add User to create role profiles for assignment.")
                )
            } else if users.isEmpty {
                ContentUnavailableView.search
            } else {
                ForEach(groupedUsers) { group in
                    ManagerUserGroupSection(
                        title: group.title,
                        users: group.users,
                        viewModel: viewModel,
                        tripsViewModel: tripsViewModel,
                        maintenanceViewModel: maintenanceViewModel
                    )
                }
            }
        }
    }

    private func makeGroups(_ definitions: [(String, (User) -> Bool)]) -> [ManagerUserGroup] {
        definitions.compactMap { title, filter in
            let grouped = users
                .filter(filter)
                .sorted {
                    $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                }

            guard grouped.isEmpty == false else { return nil }
            return ManagerUserGroup(title: title, users: grouped)
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
        return tripsViewModel.trips.contains { $0.driverId == driver.id && ($0.status == .pending || $0.status == .accepted) }
    }

    private func hasActiveWork(_ user: User) -> Bool {
        guard let personnel = maintenanceProfile(for: user) else { return false }
        return maintenanceViewModel.openTasks.contains { $0.executedBy == personnel.id }
    }

    private func matchesSearch(_ user: User, query: String) -> Bool {
        var searchable = [
            user.displayName,
            user.shortUID,
            user.id.uuidString,
            user.email,
            user.role.title,
            user.isActive ? "active" : "inactive",
            "\(user.contact)",
            user.address
        ]

        if user.role == .driver, let profile = driverProfile(for: user) {
            searchable.append(profile.licenceNum)
            searchable.append(profile.vehicleType)
            searchable.append(profile.status.title)
        }

        if user.role == .maintenancePersonnel, let profile = maintenanceProfile(for: user) {
            searchable.append(profile.status.title)
        }

        return searchable.contains {
            $0.localizedCaseInsensitiveContains(query)
        }
    }
}

private struct ManagerUserGroupSection: View {
    var title: String
    var users: [User]
    @ObservedObject var viewModel: UserManagementViewModel
    @ObservedObject var tripsViewModel: TripManagementViewModel
    @ObservedObject var maintenanceViewModel: MaintenanceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DashboardSectionTitle(title)

            GlassPanel(hasBorder: false) {
                VStack(spacing: 0) {
                    ForEach(users) { user in
                        NavigationLink {
                            ManagerUserDetailView(
                                user: user,
                                viewModel: viewModel,
                                tripsViewModel: tripsViewModel,
                                maintenanceViewModel: maintenanceViewModel
                            )
                        } label: {
                            ManagerUserCard(user: user, viewModel: viewModel)
                        }
                        .buttonStyle(.plain)

                        if user.id != users.last?.id {
                            Divider()
                                .padding(.leading, 62) // Aligns with the end of AvatarView
                        }
                    }
                }
                .padding(.vertical, -4)
            }
        }
    }
}

private struct ManagerUserCard: View {
    var user: User
    @ObservedObject var viewModel: UserManagementViewModel

    var body: some View {
        HStack(spacing: 14) {
            AvatarView(name: user.displayName, role: user.role, size: 48, imageURL: user.avatarImageURL)

            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(FleetPalette.textPrimary)
                    .lineLimit(1)

                Text(subtitleText)
                    .font(.caption)
                    .foregroundStyle(FleetPalette.textSecondary)
                    .lineLimit(1)

                Text("UID \(user.shortUID)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(FleetPalette.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(user.isActive ? "ACTIVE" : "INACTIVE")
                .font(.system(size: 8, weight: .black))
                .foregroundColor(user.isActive ? FleetPalette.success : FleetPalette.neutral)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((user.isActive ? FleetPalette.success : FleetPalette.neutral).opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityLabel("\(user.displayName), \(user.role.title)")
    }

    private var subtitleText: String {
        switch user.role {
        case .driver:
            guard let driver = viewModel.drivers.first(where: { $0.userId == user.id }) else {
                return "Driver"
            }
            return "Driver - \(driver.vehicleType.capitalized)"
        case .maintenancePersonnel:
            return "Maintenance"
        case .fleetManager:
            return "Fleet Manager"
        }
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
                    Label("Edit User", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(FleetPalette.accent)

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete User", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(FleetPalette.danger)
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
            Text("This action cannot be undone. The user and their login will be removed.")
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

                    Text(user.isActive ? "ACTIVE" : "INACTIVE")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(user.isActive ? FleetPalette.success : FleetPalette.neutral)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background((user.isActive ? FleetPalette.success : FleetPalette.neutral).opacity(0.12))
                        .clipShape(Capsule())
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
                        InfoRow(title: "Status", value: driverProfile.status.title)
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
                                    Text(task.status.title.uppercased())
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(FleetPalette.maintenanceStatus(task.status))
                                    
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
                TextField("Email / Login ID", text: $form.email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .fleetField()
                TextField("Aadhar", text: $form.aadhar)
                    .keyboardType(.numberPad)
                    .fleetField()
                TextField("Contact", text: $form.contact)
                    .keyboardType(.phonePad)
                    .fleetField()
                TextField("Address", text: $form.address, axis: .vertical)
                    .lineLimit(2...4)
                    .fleetField()
                TextField("Photo / DP URL", text: $form.avatarUrl)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .fleetField()

                if user.role == .driver {
                    TextField("Licence number", text: $form.licenceNumber)
                        .textInputAutocapitalization(.characters)
                        .fleetField()

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
                        var updated = user
                        let nameParts = form.normalizedNameParts
                        updated.fName = nameParts.first
                        updated.lName = nameParts.last
                        updated.email = form.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        updated.aadhar = form.aadhar.trimmingCharacters(in: .whitespacesAndNewlines)
                        updated.address = form.address.trimmingCharacters(in: .whitespacesAndNewlines)
                        updated.avatarUrl = form.normalizedAvatarUrl
                        if let contact = form.contactValue {
                            updated.contact = contact
                        }
                        let userSaved = await viewModel.updateUser(updated)
                        let driverSaved = user.role == .driver
                            ? await viewModel.updateDriverProfile(
                                userId: user.id,
                                licenceNumber: form.licenceNumber,
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
    }
}

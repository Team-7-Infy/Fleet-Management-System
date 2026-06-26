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
                ("Registered", { $0.isActive && isDriverOnTrip($0) == false && isDriverAssigned($0) == false }),
                ("Inactive", { $0.isActive == false })
            ])
        case .maintenance:
            return makeGroups([
                ("Assigned Work", { $0.isActive && hasActiveWork($0) }),
                ("Registered", { $0.isActive && hasActiveWork($0) == false }),
                ("Inactive", { $0.isActive == false })
            ])
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScreenHeader(title: "Users")
                FleetSearchBar(text: $searchText)
                FeedbackView(success: viewModel.successMessage, error: viewModel.errorMessage)
                userList
            }
            .padding(.horizontal)
            .padding(.top, 4)
            .padding(.bottom, 16)
        }
        .fleetScreenBackground()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await viewModel.load()
            await tripsViewModel.load()
            await maintenanceViewModel.load()
        }
    }

    private var userList: some View {
        VStack(spacing: 14) {
            if baseUsers.isEmpty {
                GlassPanel {
                    EmptyStateView(
                        title: selectedSegment.emptyTitle,
                        message: "Use the plus button to create role profiles for assignment.",
                        systemImage: "person.2.slash"
                    )
                }
            } else if users.isEmpty {
                GlassPanel {
                    EmptyStateView(
                        title: "No matching users",
                        message: "Try a different name, email, phone, role, status, licence, or vehicle type.",
                        systemImage: "magnifyingglass"
                    )
                }
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
                            .padding(.leading, 86)
                    }
                }
            }
            .background(FleetPalette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(FleetPalette.tertiary.opacity(0.45), lineWidth: 1)
            }
        }
    }
}

private struct ManagerUserCard: View {
    var user: User
    @ObservedObject var viewModel: UserManagementViewModel

    var body: some View {
        HStack(spacing: 14) {
            AvatarView(name: user.displayName, role: user.role, imageURL: user.avatarImageURL)

            VStack(alignment: .leading, spacing: 5) {
                Text(user.displayName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(FleetPalette.textPrimary)
                    .lineLimit(1)

                Text(subtitleText)
                    .font(.subheadline)
                    .foregroundStyle(FleetPalette.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            StatusPill(
                text: user.isActive ? "Active" : "Inactive",
                color: user.isActive ? FleetPalette.success : FleetPalette.neutral
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FleetPalette.surface)
        .accessibilityLabel("\(user.displayName), \(user.role.title)")
    }

    private var subtitleText: String {
        switch user.role {
        case .driver:
            guard let driver = viewModel.drivers.first(where: { $0.userId == user.id }) else {
                return "Driver profile pending"
            }
            return "\(driver.vehicleType.capitalized) - \(driver.licenceNum)"
        case .maintenancePersonnel:
            let status = viewModel.maintenancePersonnel.first(where: { $0.userId == user.id })?.status.title ?? "Profile pending"
            return "Maintenance - \(status)"
        case .fleetManager:
            return user.email
        }
    }
}

private struct ManagerUserDetailView: View {
    @Environment(\.dismiss) private var dismiss
    var user: User
    @ObservedObject var viewModel: UserManagementViewModel
    @ObservedObject var tripsViewModel: TripManagementViewModel
    @ObservedObject var maintenanceViewModel: MaintenanceViewModel

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
                header

                switch user.role {
                case .driver:
                    driverDetails
                case .maintenancePersonnel:
                    maintenanceDetails
                case .fleetManager:
                    managerDetails
                }

                Button {
                    Task {
                        await viewModel.setActive(user, isActive: user.isActive == false)
                        dismiss()
                    }
                } label: {
                    Label(user.isActive ? "Deactivate User" : "Activate User", systemImage: user.isActive ? "pause.circle" : "play.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(user.isActive ? FleetPalette.warning : FleetPalette.success)
            }
            .padding()
        }
        .fleetScreenBackground()
        .navigationTitle(user.role == .driver ? "Driver Details" : "User Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        GlassPanel {
            HStack(spacing: 14) {
                AvatarView(name: user.displayName, role: user.role, size: 86, imageURL: user.avatarImageURL)

                VStack(alignment: .leading, spacing: 6) {
                    Text(user.displayName)
                        .font(.title3.bold())
                        .foregroundStyle(FleetPalette.textPrimary)
                    Text(user.email)
                        .font(.subheadline)
                        .foregroundStyle(FleetPalette.textSecondary)
                    HStack {
                        StatusPill(text: user.role.title, color: FleetPalette.primary)
                        StatusPill(
                            text: user.isActive ? "Active" : "Inactive",
                            color: user.isActive ? FleetPalette.success : FleetPalette.neutral
                        )
                    }
                }
            }
        }
    }

    private var driverDetails: some View {
        GlassPanel {
            if let driverProfile {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Driver Profile")
                        .font(.title3.bold())
                    InfoRow(title: "Phone", value: "\(user.contact)")
                    InfoRow(title: "Aadhar", value: user.aadhar)
                    InfoRow(title: "License", value: driverProfile.licenceNum)
                    InfoRow(title: "Vehicle Type", value: driverProfile.vehicleType.capitalized)
                    InfoRow(title: "Trips", value: "\(driverTrips.count)")
                    InfoRow(title: "Address", value: user.address)
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

    private var maintenanceDetails: some View {
        GlassPanel {
            if let maintenanceProfile {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Maintenance Profile")
                        .font(.title3.bold())
                    InfoRow(title: "Phone", value: "\(user.contact)")
                    InfoRow(title: "Aadhar", value: user.aadhar)
                    InfoRow(title: "Status", value: maintenanceProfile.status.title)
                    InfoRow(title: "Work Orders", value: "\(workOrders.count)")
                    InfoRow(title: "Address", value: user.address)
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

    private var managerDetails: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text("Manager Profile")
                    .font(.title3.bold())
                InfoRow(title: "Phone", value: "\(user.contact)")
                InfoRow(title: "Aadhar", value: user.aadhar)
                InfoRow(title: "Address", value: user.address)
            }
        }
    }
}

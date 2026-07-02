import SwiftUI
import MapKit

private enum ManagerTripFilter: String, CaseIterable, Identifiable {
    case all
    case live
    case scheduled
    case history

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .live: return "Live"
        case .scheduled: return "Scheduled"
        case .history: return "History"
        }
    }

    func includes(_ trip: Trip) -> Bool {
        switch self {
        case .all:
            return true
        case .live:
            return trip.status == .accepted || trip.status == .inProgress
        case .scheduled:
            return trip.status == .pending || trip.status == .rejectionPending
        case .history:
            return trip.status == .completed || trip.status == .rejected
        }
    }
}

struct ManagerTripGroup: Identifiable {
    var id: String { title }
    var title: String
    var trips: [Trip]
}

struct ManagerTripsView: View {
    @ObservedObject var viewModel: TripManagementViewModel
    @ObservedObject var vehiclesViewModel: VehicleViewModel
    @ObservedObject var usersViewModel: UserManagementViewModel

    @State private var searchText = ""
    @State private var filter: ManagerTripFilter = .all

    var openAddTrip: () -> Void

    private var groupedTrips: [ManagerTripGroup] {
        [
            ManagerTripGroup(title: "Live", trips: liveTrips),
            ManagerTripGroup(title: "Scheduled", trips: scheduledTrips),
            ManagerTripGroup(title: "History", trips: historyTrips)
        ]
        .filter { $0.trips.isEmpty == false }
    }

    private var filteredTrips: [Trip] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let visible = viewModel.trips
            .filter { filter.includes($0) }
            .filter { trip in
                guard query.isEmpty == false else { return true }
                return matchesSearch(trip, query: query)
            }

        return visible.sorted { $0.startTime > $1.startTime }
    }

    private var liveTrips: [Trip] {
        filteredTrips
            .filter { $0.status == .accepted || $0.status == .inProgress }
    }

    private var scheduledTrips: [Trip] {
        filteredTrips
            .filter { $0.status == .pending || $0.status == .rejectionPending }
    }

    private var historyTrips: [Trip] {
        filteredTrips
            .filter { $0.status == .completed || $0.status == .rejected }
    }

    var body: some View {
        ManagerTripListScreen(
            groups: groupedTrips,
            emptyTitle: "No active or scheduled trips",
            emptyMessage: "Use Add Trip to create a trip with a vehicle and driver.",
            viewModel: viewModel,
            vehiclesViewModel: vehiclesViewModel,
            usersViewModel: usersViewModel
        )
        .navigationTitle("Trips")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search trips")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                TripFilterMenu(filter: $filter)
                Button("Add Trip", systemImage: "plus", action: openAddTrip)
            }
        }
        .refreshable {
            await viewModel.load()
        }
    }

    private func matchesSearch(_ trip: Trip, query: String) -> Bool {
        let vehicle = vehiclesViewModel.vehicle(for: trip.vehicleId)
        let driver = usersViewModel.driverUser(for: trip.driverId)
        return [
            trip.startLocation,
            trip.endLocation,
            trip.status.title,
            vehicle?.licencePlate,
            vehicle.map { "\($0.make) \($0.model)" },
            driver?.displayName,
            driver.map { "\($0.contact)" }
        ]
        .compactMap { $0 }
        .contains { $0.localizedCaseInsensitiveContains(query) }
    }
}

private struct ManagerTripListScreen: View {
    var groups: [ManagerTripGroup]
    var emptyTitle: String
    var emptyMessage: String
    @ObservedObject var viewModel: TripManagementViewModel
    @ObservedObject var vehiclesViewModel: VehicleViewModel
    @ObservedObject var usersViewModel: UserManagementViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FeedbackView(success: viewModel.successMessage, error: viewModel.errorMessage)

                if !viewModel.rejectionRequests.isEmpty {
                    RejectionRequestsSection(
                        trips: viewModel.rejectionRequests,
                        viewModel: viewModel,
                        vehiclesViewModel: vehiclesViewModel,
                        usersViewModel: usersViewModel
                    )
                }

                if groups.isEmpty {
                    ContentUnavailableView(
                        emptyTitle,
                        systemImage: "road.lanes",
                        description: Text(emptyMessage)
                    )
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(groups) { group in
                            ManagerTripGroupSection(
                                title: group.title,
                                trips: group.trips,
                                viewModel: viewModel,
                                vehiclesViewModel: vehiclesViewModel,
                                usersViewModel: usersViewModel
                            )
                        }
                    }
                }
            }
            .padding()
        }
        .fleetScreenBackground()
    }
}

private struct TripFilterMenu: View {
    @Binding var filter: ManagerTripFilter

    var body: some View {
        Menu("Filter", systemImage: "line.3.horizontal.decrease.circle") {
            Picker("Trip filter", selection: $filter) {
                ForEach(ManagerTripFilter.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
        }
    }
}

private struct ManagerTripGroupSection: View {
    var title: String
    var trips: [Trip]
    @ObservedObject var viewModel: TripManagementViewModel
    @ObservedObject var vehiclesViewModel: VehicleViewModel
    @ObservedObject var usersViewModel: UserManagementViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.title3.weight(.heavy))
                .foregroundStyle(Color(hex: 0x607086))
                .padding(.horizontal, 2)

            LazyVStack(spacing: 14) {
                ForEach(trips) { trip in
                    NavigationLink {
                        ManagerTripDetailView(
                            trip: trip,
                            viewModel: viewModel,
                            vehiclesViewModel: vehiclesViewModel,
                            usersViewModel: usersViewModel
                        )
                    } label: {
                        ManagerTripCard(
                            trip: trip,
                            vehicle: vehiclesViewModel.vehicle(for: trip.vehicleId),
                            driver: usersViewModel.driverUser(for: trip.driverId)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct ManagerTripCard: View {
    var trip: Trip
    var vehicle: Vehicle?
    var driver: User?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                TripRouteGlyph()

                VStack(alignment: .leading, spacing: 7) {
                    Text(trip.startLocation)
                        .font(.title3.bold())
                        .foregroundStyle(FleetPalette.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(trip.endLocation)
                        .font(.title3.bold())
                        .foregroundStyle(FleetPalette.textPrimary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                TripCardStatusBadge(text: trip.status.title, color: FleetPalette.tripStatus(trip.status))
            }

            VStack(spacing: 0) {
                TripOverviewRow(
                    systemImage: "calendar",
                    title: "Start",
                    value: FleetManagerFormat.shortDateTime.string(from: trip.startTime)
                )

                Divider()

                TripOverviewRow(
                    systemImage: "clock",
                    title: trip.endTime == nil ? "ETA" : "Stop",
                    value: trip.endTime.map { FleetManagerFormat.shortDateTime.string(from: $0) } ?? "TBD"
                )

                Divider()

                TripPersonOverviewRow(
                    systemImage: "person.fill",
                    title: driver?.displayName ?? "Driver unavailable",
                    value: driver.map { "Contact: \($0.contact)" } ?? nil
                )

                Divider()

                TripVehicleInfoRow(
                    vehicle: vehicle,
                    title: vehicle?.licencePlate ?? "Vehicle unavailable",
                    value: vehicle.map { "\($0.year) \($0.make) \($0.model)" }
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(FleetPalette.background, in: RoundedRectangle(cornerRadius: 16))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FleetPalette.surface, in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(FleetPalette.tertiary.opacity(0.42), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct TripCardStatusBadge: View {
    var text: String
    var color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(FleetPalette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.top, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

private struct TripRouteGlyph: View {
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "mappin.circle.fill")
                .font(.title2.weight(.bold))
                .foregroundStyle(FleetPalette.accent)

            VStack(spacing: 3) {
                ForEach(0..<4, id: \.self) { _ in
                    Circle()
                        .fill(FleetPalette.accent.opacity(0.62))
                        .frame(width: 4, height: 4)
                }
            }

            Image(systemName: "mappin.circle.fill")
                .font(.title2.weight(.bold))
                .foregroundStyle(FleetPalette.accent)
        }
        .frame(width: 34)
    }
}

private struct TripOverviewRow: View {
    var systemImage: String
    var title: String
    var value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(FleetPalette.accent)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FleetPalette.textSecondary)

                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FleetPalette.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
    }
}

private struct TripPersonOverviewRow: View {
    var systemImage: String
    var title: String
    var value: String?

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(FleetPalette.accent)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline.bold())
                    .foregroundStyle(FleetPalette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                if let value, value.isEmpty == false {
                    Text(value)
                        .font(.subheadline)
                        .foregroundStyle(FleetPalette.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TripVehicleInfoRow: View {
    var vehicle: Vehicle?
    var title: String
    var value: String?

    var body: some View {
        HStack(spacing: 14) {
            VehicleAssetImage(vehicle: vehicle, width: 62, height: 48, cornerRadius: 12)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline.bold())
                    .foregroundStyle(FleetPalette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                if let value, value.isEmpty == false {
                    Text(value)
                        .font(.subheadline)
                        .foregroundStyle(FleetPalette.textSecondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ManagerTripDetailView: View {
    var trip: Trip
    @ObservedObject var viewModel: TripManagementViewModel
    @ObservedObject var vehiclesViewModel: VehicleViewModel
    @ObservedObject var usersViewModel: UserManagementViewModel
    @State private var driverMessage = ""

    private var currentTrip: Trip {
        viewModel.trip(for: trip.id) ?? trip
    }

    private var isLive: Bool {
        currentTrip.status == .accepted || currentTrip.status == .inProgress
    }

    private var vehicle: Vehicle? {
        vehiclesViewModel.vehicle(for: currentTrip.vehicleId)
    }

    private var driver: User? {
        usersViewModel.driverUser(for: currentTrip.driverId)
    }

    private var driverProfile: Driver? {
        usersViewModel.driver(for: currentTrip.driverId)
    }

    private var driverTrips: [Trip] {
        guard let driverId = currentTrip.driverId else { return [] }
        return viewModel.trips
            .filter { $0.driverId == driverId }
            .sorted { $0.startTime > $1.startTime }
    }

    private var vehicleTrips: [Trip] {
        viewModel.trips
            .filter { $0.vehicleId == currentTrip.vehicleId }
            .sorted { $0.startTime > $1.startTime }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                routeHero
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()

                ScrollView {
                    Color.clear
                        .frame(height: max(proxy.size.height * 0.56, 340))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 18) {
                        Capsule()
                            .fill(FleetPalette.textTertiary.opacity(0.35))
                            .frame(width: 42, height: 5)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 10)
                            .accessibilityHidden(true)

                        routeDetails
                        driverCard
                        vehicleCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 110)
                    .background(.ultraThinMaterial, in: UnevenRoundedRectangle(topLeadingRadius: 32, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 32, style: .continuous))
                    .overlay(alignment: .top) {
                        UnevenRoundedRectangle(topLeadingRadius: 32, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 32, style: .continuous)
                            .stroke(.white.opacity(0.42), lineWidth: 1)
                    }
                }
                .scrollIndicators(.hidden)
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .background(FleetPalette.background.ignoresSafeArea())
        .navigationTitle(isLive ? "Live Trip" : currentTrip.status == .completed ? "Trip History" : "Scheduled Trip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
    }

    private var routeHero: some View {
        RouteMapPreview(
            startLocation: currentTrip.startLocation,
            endLocation: currentTrip.endLocation
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Route map from \(currentTrip.startLocation) to \(currentTrip.endLocation)")
    }

    private var routeDetails: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text("Route Details")
                    .font(.title3.weight(.bold))
                InfoRow(title: "Pickup", value: currentTrip.startLocation)
                InfoRow(title: "Destination", value: currentTrip.endLocation)
                InfoRow(title: "Status", value: currentTrip.status.title)
                InfoRow(title: "Start", value: FleetManagerFormat.shortDateTime.string(from: currentTrip.startTime))
                InfoRow(
                    title: currentTrip.endTime == nil ? "ETA" : "Stop",
                    value: currentTrip.endTime.map { FleetManagerFormat.shortDateTime.string(from: $0) } ?? "TBD"
                )
                TripRouteEstimateSummary(
                    startLocation: currentTrip.startLocation,
                    endLocation: currentTrip.endLocation,
                    startTime: currentTrip.startTime
                )
                InfoRow(title: "Cost", value: "Not recorded")
                InfoRow(title: "Fuel Receipt", value: "Not uploaded")
            }
        }
    }

    private var driverCard: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                if let driver {
                    NavigationLink {
                        TripDriverDetailView(
                            user: driver,
                            driver: driverProfile,
                            trips: driverTrips
                        )
                    } label: {
                        driverSummaryRow(driver: driver)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens driver details")
                } else {
                    driverSummaryRow(driver: nil)
                }

                if driver != nil {
                    HStack(spacing: 10) {
                        TextField("Message driver", text: $driverMessage)
                            .font(.subheadline)
                            .textInputAutocapitalization(.sentences)

                        Button {
                            driverMessage = ""
                        } label: {
                            Image(systemName: "paperplane.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(FleetPalette.accent, in: Circle())
                        }
                        .disabled(driverMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(driverMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
                        .accessibilityLabel("Send message")
                    }
                    .padding(.leading, 12)
                    .padding(.trailing, 6)
                    .frame(height: 46)
                    .background(FleetPalette.background, in: Capsule())
                }
            }
        }
    }

    private func driverSummaryRow(driver: User?) -> some View {
        HStack(alignment: .center, spacing: 14) {
            AvatarView(name: driver?.displayName ?? "Driver", role: .driver, size: 58, imageURL: driver?.avatarImageURL)

            VStack(alignment: .leading, spacing: 7) {
                Text(driver?.displayName ?? "Driver unavailable")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(FleetPalette.textPrimary)
                    .lineLimit(1)

                Text(driver?.email ?? "No assigned user record")
                    .font(.subheadline)
                    .foregroundStyle(FleetPalette.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if driver != nil {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FleetPalette.textTertiary)
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var vehicleCard: some View {
        if let vehicle {
            NavigationLink {
                TripVehicleDetailView(
                    vehicle: vehicle,
                    assignedDriver: driver,
                    trips: vehicleTrips
                )
            } label: {
                vehicleSummaryCard(vehicle)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens vehicle details")
        } else {
            GlassPanel {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Vehicle")
                        .font(.title3.weight(.bold))

                    EmptyStateView(
                        title: "Vehicle unavailable",
                        message: "The assigned vehicle could not be found.",
                        systemImage: "car.slash"
                    )
                }
            }
        }
    }

    private func vehicleSummaryCard(_ vehicle: Vehicle) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    VehicleAssetImage(vehicle: vehicle, width: 86, height: 64, cornerRadius: 17)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Vehicle")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(FleetPalette.textPrimary)
                        Text(vehicle.licencePlate)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(FleetPalette.textPrimary)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(FleetPalette.textTertiary)
                }

                InfoRow(title: "Number", value: vehicle.licencePlate)
                InfoRow(title: "Model", value: "\(vehicle.year) \(vehicle.make) \(vehicle.model)")
                InfoRow(title: "Type", value: vehicle.vehicleType.capitalized)
                InfoRow(title: "Status", value: vehicle.status.title)
            }
        }
        .contentShape(Rectangle())
    }

}

private struct TripDriverDetailView: View {
    var user: User
    var driver: Driver?
    var trips: [Trip]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                GlassPanel {
                    HStack(spacing: 16) {
                        AvatarView(name: user.displayName, role: .driver, size: 78, imageURL: user.avatarImageURL)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(user.displayName)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(FleetPalette.textPrimary)
                            Text(user.email)
                                .font(.subheadline)
                                .foregroundStyle(FleetPalette.textSecondary)
                        }

                        Spacer(minLength: 0)
                    }
                }

                GlassPanel {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("User Details")
                            .font(.title3.bold())
                        InfoRow(title: "Email", value: user.email)
                        InfoRow(title: "Contact", value: "\(user.contact)")
                        InfoRow(title: "UID", value: user.id.uuidString)
                        InfoRow(title: "Aadhaar", value: user.aadhar.isEmpty ? "Not recorded" : user.aadhar)
                        InfoRow(title: "Address", value: user.address.isEmpty ? "Not recorded" : user.address)
                    }
                }

                GlassPanel {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Driver Profile")
                            .font(.title3.bold())

                        if let driver {
                            InfoRow(title: "Licence", value: driver.licenceNum)
                            InfoRow(title: "Vehicle Type", value: driver.vehicleType.capitalized)
                            InfoRow(title: "Status", value: driver.status.title)
                            InfoRow(title: "Trips", value: "\(trips.count)")
                        } else {
                            EmptyStateView(
                                title: "Profile unavailable",
                                message: "The driver profile record could not be found.",
                                systemImage: "person.text.rectangle"
                            )
                        }
                    }
                }

                LinkedTripsSection(title: "Driver Trips", trips: trips)
            }
            .padding()
            .padding(.bottom, 32)
        }
        .fleetScreenBackground()
        .navigationTitle("Driver Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TripVehicleDetailView: View {
    var vehicle: Vehicle
    var assignedDriver: User?
    var trips: [Trip]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                GlassPanel {
                    HStack(spacing: 16) {
                        VehicleAssetImage(vehicle: vehicle, width: 104, height: 76, cornerRadius: 18)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(vehicle.licencePlate)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(FleetPalette.textPrimary)
                            Text("\(vehicle.year) \(vehicle.make) \(vehicle.model)")
                                .font(.subheadline)
                                .foregroundStyle(FleetPalette.textSecondary)
                        }

                        Spacer(minLength: 0)
                    }
                }

                GlassPanel {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Fleet Details")
                            .font(.title3.bold())
                        InfoRow(title: "Plate Number", value: vehicle.licencePlate)
                        InfoRow(title: "VIN", value: vehicle.id.uuidString)
                        InfoRow(title: "Make", value: vehicle.make)
                        InfoRow(title: "Model", value: vehicle.model)
                        InfoRow(title: "Year", value: "\(vehicle.year)")
                        InfoRow(title: "Type", value: vehicle.vehicleType.capitalized)
                        InfoRow(title: "Status", value: vehicle.status.title)
                    }
                }

                GlassPanel {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Assignment")
                            .font(.title3.bold())

                        if let assignedDriver {
                            InfoRow(title: "Assigned Driver", value: assignedDriver.displayName)
                            InfoRow(title: "Contact", value: "\(assignedDriver.contact)")
                            InfoRow(title: "Email", value: assignedDriver.email)
                        } else {
                            EmptyStateView(
                                title: "Unassigned",
                                message: "This vehicle is available for a new trip assignment.",
                                systemImage: "person.crop.circle.badge.questionmark"
                            )
                        }
                    }
                }

                LinkedTripsSection(title: "Vehicle Trips", trips: trips)
            }
            .padding()
            .padding(.bottom, 32)
        }
        .fleetScreenBackground()
        .navigationTitle("Vehicle Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LinkedTripsSection: View {
    var title: String
    var trips: [Trip]

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.title3.bold())

                if trips.isEmpty {
                    EmptyStateView(
                        title: "No linked trips",
                        message: "Trips connected to this record will appear here.",
                        systemImage: "road.lanes"
                    )
                } else {
                    ForEach(Array(trips.prefix(5))) { trip in
                        TripLinkedRow(trip: trip)

                        if trip.id != trips.prefix(5).last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

private struct TripLinkedRow: View {
    var trip: Trip

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            TripRouteGlyph()

            VStack(alignment: .leading, spacing: 5) {
                Text(trip.startLocation)
                    .font(.headline)
                    .foregroundStyle(FleetPalette.textPrimary)
                    .lineLimit(1)
                Text(trip.endLocation)
                    .font(.subheadline)
                    .foregroundStyle(FleetPalette.textSecondary)
                    .lineLimit(1)
                Text(FleetManagerFormat.shortDateTime.string(from: trip.startTime))
                    .font(.caption)
                    .foregroundStyle(FleetPalette.textSecondary)
            }

            Spacer(minLength: 8)

            Text(trip.status.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(FleetPalette.textSecondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }
}

private struct RouteMapPreview: View {
    var startLocation: String
    var endLocation: String
    @State private var pickup: TripPlace?
    @State private var destination: TripPlace?
    @State private var estimate: TripRouteEstimate?
    @State private var position: MapCameraPosition = .automatic
    @State private var isLoading = false

    var body: some View {
        Map(position: $position, interactionModes: []) {
            if let estimate {
                MapPolyline(estimate.route.polyline)
                    .stroke(FleetPalette.accent, lineWidth: 6)
            }

            if let pickup {
                Marker("Pickup", systemImage: "mappin.circle.fill", coordinate: pickup.coordinate)
                    .tint(FleetPalette.success)
            }

            if let destination {
                Marker("Destination", systemImage: "flag.checkered", coordinate: destination.coordinate)
                    .tint(FleetPalette.accent)
            }
        }
        .overlay {
            if isLoading {
                ProgressView("Loading route")
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
            } else if pickup == nil || destination == nil {
                VStack(spacing: 8) {
                    Image(systemName: "map")
                        .font(.title2.weight(.semibold))
                    Text("Route map unavailable")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(FleetPalette.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial, in: Capsule())
            }
        }
        .allowsHitTesting(false)
        .task(id: "\(startLocation)|\(endLocation)") {
            await loadRoute()
        }
    }

    @MainActor
    private func loadRoute() async {
        isLoading = true
        defer { isLoading = false }

        do {
            guard let resolvedPickup = try await TripRouteEstimator.resolvePlace(named: startLocation),
                  let resolvedDestination = try await TripRouteEstimator.resolvePlace(named: endLocation)
            else {
                pickup = nil
                destination = nil
                estimate = nil
                return
            }

            pickup = resolvedPickup
            destination = resolvedDestination
            estimate = try await TripRouteEstimator.estimateRoute(
                from: resolvedPickup,
                to: resolvedDestination,
                startTime: Date()
            )
            position = .automatic
        } catch {
            estimate = nil
        }
    }
}

private struct TripRouteEstimateSummary: View {
    var startLocation: String
    var endLocation: String
    var startTime: Date
    @State private var estimate: TripRouteEstimate?

    var body: some View {
        Group {
            if let estimate {
                InfoRow(title: "Travel Time", value: estimate.durationText)
                InfoRow(title: "Distance", value: estimate.distanceText)
            }
        }
        .task(id: "\(startLocation)|\(endLocation)|\(startTime.timeIntervalSince1970)") {
            await loadEstimate()
        }
    }

    @MainActor
    private func loadEstimate() async {
        do {
            guard let pickup = try await TripRouteEstimator.resolvePlace(named: startLocation),
                  let destination = try await TripRouteEstimator.resolvePlace(named: endLocation)
            else {
                estimate = nil
                return
            }

            estimate = try await TripRouteEstimator.estimateRoute(
                from: pickup,
                to: destination,
                startTime: startTime
            )
        } catch {
            estimate = nil
        }
    }
}

private struct RejectionRequestsSection: View {
    var trips: [Trip]
    @ObservedObject var viewModel: TripManagementViewModel
    @ObservedObject var vehiclesViewModel: VehicleViewModel
    @ObservedObject var usersViewModel: UserManagementViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("REJECTION REQUESTS")
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(FleetPalette.danger)
                Spacer()
                Text("\(trips.count) pending")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(FleetPalette.danger)
                    .cornerRadius(8)
            }
            .padding(.horizontal, 2)

            LazyVStack(spacing: 14) {
                ForEach(trips) { trip in
                    RejectionRequestCard(
                        trip: trip,
                        viewModel: viewModel,
                        vehicle: vehiclesViewModel.vehicle(for: trip.vehicleId),
                        driver: usersViewModel.driverUser(for: trip.driverId)
                    )
                }
            }
        }
    }
}

private struct RejectionRequestCard: View {
    var trip: Trip
    @ObservedObject var viewModel: TripManagementViewModel
    var vehicle: Vehicle?
    var driver: User?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.startLocation)
                        .font(.headline)
                    Text(trip.endLocation)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                StatusDot(text: "Rejection Pending", color: FleetPalette.danger)
            }

            if let driver {
                Label(driver.displayName, systemImage: "person.fill")
                    .font(.subheadline)
            }

            if let reason = trip.rejectionReason, !reason.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reason:")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(FleetPalette.danger)
                    Text(reason)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(FleetPalette.danger.opacity(0.05))
                .cornerRadius(8)
            }

            HStack(spacing: 12) {
                Button {
                    Task { await viewModel.approveRejection(for: trip) }
                } label: {
                    Label("Approve", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(FleetPalette.danger)

                Button {
                    Task { await viewModel.denyRejection(for: trip) }
                } label: {
                    Label("Deny", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(FleetPalette.success)
            }
        }
        .padding(16)
        .background(FleetPalette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(FleetPalette.danger.opacity(0.3), lineWidth: 1)
        }
    }
}

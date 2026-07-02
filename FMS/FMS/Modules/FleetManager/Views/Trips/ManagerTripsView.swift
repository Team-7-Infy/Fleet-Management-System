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

private enum ManagerTripSort: String, CaseIterable, Identifiable {
    case newest
    case oldest
    case status

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newest: return "Newest"
        case .oldest: return "Oldest"
        case .status: return "Status"
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
    @State private var sort: ManagerTripSort = .newest

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

        switch sort {
        case .newest:
            return visible.sorted { $0.startTime > $1.startTime }
        case .oldest:
            return visible.sorted { $0.startTime < $1.startTime }
        case .status:
            return visible.sorted {
                if $0.status.rawValue == $1.status.rawValue {
                    return $0.startTime > $1.startTime
                }
                return $0.status.title.localizedCaseInsensitiveCompare($1.status.title) == .orderedAscending
            }
        }
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
                TripSortMenu(sort: $sort)
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

private struct TripSortMenu: View {
    @Binding var sort: ManagerTripSort

    var body: some View {
        Menu("Sort", systemImage: "arrow.up.arrow.down.circle") {
            Picker("Trip sort", selection: $sort) {
                ForEach(ManagerTripSort.allCases) { option in
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
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 15) {
                TripRouteGlyph()

                VStack(alignment: .leading, spacing: 10) {
                    Text(trip.startLocation)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(FleetPalette.textPrimary)
                        .lineLimit(2)

                    Text(trip.endLocation)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(FleetPalette.textPrimary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                StatusDot(text: trip.status.title, color: FleetPalette.tripStatus(trip.status))
            }

            LazyVGrid(columns: FleetPalette.twoColumnGrid, spacing: 10) {
                TripInfoTile(
                    systemImage: "clock",
                    title: "Start",
                    value: FleetManagerFormat.shortDateTime.string(from: trip.startTime)
                )

                TripInfoTile(
                    systemImage: "clock",
                    title: trip.endTime == nil ? "ETA" : "Stop",
                    value: trip.endTime.map { FleetManagerFormat.shortDateTime.string(from: $0) } ?? "TBD"
                )
            }

            VStack(spacing: 10) {
                TripInfoRow(
                    systemImage: "person.fill",
                    title: driver?.displayName ?? "Driver unavailable",
                    value: driver.map { "Contact: \($0.contact)" } ?? nil
                )

                TripVehicleInfoRow(
                    vehicle: vehicle,
                    title: vehicle?.licencePlate ?? "Vehicle unavailable",
                    value: vehicle.map { "\($0.year) \($0.make) \($0.model)" }
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FleetPalette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(FleetPalette.tertiary.opacity(0.55), lineWidth: 1)
        }
        .shadow(color: FleetPalette.accent.opacity(0.10), radius: 16, x: 0, y: 9)
        .accessibilityElement(children: .combine)
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

private struct TripInfoTile: View {
    var systemImage: String
    var title: String
    var value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(FleetPalette.accent)
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(FleetPalette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(FleetPalette.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: 74)
        .background(FleetPalette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(FleetPalette.tertiary.opacity(0.70), lineWidth: 1)
        }
    }
}

private struct TripInfoRow: View {
    var systemImage: String
    var title: String
    var value: String?

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(FleetPalette.accent)
                .frame(width: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline.weight(.semibold))
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

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 72)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FleetPalette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(FleetPalette.tertiary.opacity(0.70), lineWidth: 1)
        }
    }
}

private struct TripVehicleInfoRow: View {
    var vehicle: Vehicle?
    var title: String
    var value: String?

    var body: some View {
        HStack(spacing: 14) {
            VehicleAssetImage(vehicle: vehicle, width: 58, height: 46, cornerRadius: 13)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline.weight(.semibold))
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

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 72)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FleetPalette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(FleetPalette.tertiary.opacity(0.70), lineWidth: 1)
        }
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                routeHero

                VStack(alignment: .leading, spacing: 18) {
                    routeDetails
                    driverCard
                    vehicleCard
                }
                .padding()
            }
            .padding(.bottom, 12)
        }
        .background(FleetPalette.background.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
        .navigationTitle(isLive ? "Live Trip" : currentTrip.status == .completed ? "Trip History" : "Scheduled Trip")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var routeHero: some View {
        ZStack(alignment: .bottomLeading) {
            RouteMapPreview(
                startLocation: currentTrip.startLocation,
                endLocation: currentTrip.endLocation,
                isLive: isLive
            )
                .frame(height: 330)

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    IconBubble(systemImage: isLive ? "location.north.line.fill" : "calendar", tint: .white)
                    StatusDot(text: currentTrip.status.title, color: FleetPalette.tripStatus(currentTrip.status))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Map View")
                        .font(.title2.weight(.bold))
                    Text("\(currentTrip.startLocation) to \(currentTrip.endLocation)")
                        .font(.headline)
                        .lineLimit(3)
                }
                .foregroundStyle(.white)

                RouteTimeline(start: currentTrip.startLocation, end: currentTrip.endLocation)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    private var routeDetails: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Route Details")
                        .font(.title3.weight(.bold))
                    Spacer()
                    StatusDot(text: currentTrip.status.title, color: FleetPalette.tripStatus(currentTrip.status))
                }
                InfoRow(title: "Pickup", value: currentTrip.startLocation)
                InfoRow(title: "Destination", value: currentTrip.endLocation)
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
            HStack(alignment: .top, spacing: 14) {
                AvatarView(name: driver?.displayName ?? "Driver", role: .driver, size: 58, imageURL: driver?.avatarImageURL)

                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(driver?.displayName ?? "Driver unavailable")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(FleetPalette.textPrimary)
                        Spacer()
                        StatusDot(text: isLive ? "Assigned" : "Pending", color: isLive ? FleetPalette.success : FleetPalette.warning)
                    }

                    if let driver {
                        Text(driver.email)
                            .font(.subheadline)
                            .foregroundStyle(FleetPalette.textSecondary)
                    }

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
                    .padding(.top, 4)
                }
            }
        }
    }

    private var vehicleCard: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                if let vehicle {
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

                        StatusDot(text: vehicle.status.title, color: FleetPalette.vehicleStatus(vehicle.status))
                    }

                    InfoRow(title: "Number", value: vehicle.licencePlate)
                    InfoRow(title: "Model", value: "\(vehicle.year) \(vehicle.make) \(vehicle.model)")
                    InfoRow(title: "Type", value: vehicle.vehicleType.capitalized)
                    InfoRow(title: "Status", value: vehicle.status.title)
                } else {
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

}

private struct RouteMapPreview: View {
    var startLocation: String
    var endLocation: String
    var isLive: Bool
    @State private var pickup: TripPlace?
    @State private var destination: TripPlace?
    @State private var estimate: TripRouteEstimate?
    @State private var position: MapCameraPosition = .automatic
    @State private var isLoading = false

    var body: some View {
        Map(position: $position) {
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
        .overlay(alignment: .topTrailing) {
            Label(isLive ? "Live" : "Planned", systemImage: isLive ? "dot.radiowaves.left.and.right" : "map")
                .font(.caption.weight(.bold))
                .foregroundStyle(FleetPalette.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.white.opacity(0.94), in: Capsule())
                .padding(.top, 70)
                .padding(.trailing, 20)
        }
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

private struct RouteTimeline: View {
    var start: String
    var end: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TimelinePoint(title: "Start", value: start, systemImage: "circle.fill")
            Rectangle()
                .fill(.white.opacity(0.6))
                .frame(width: 2, height: 24)
                .padding(.leading, 11)
            TimelinePoint(title: "End", value: end, systemImage: "mappin.circle.fill")
        }
    }
}

private struct TimelinePoint: View {
    var title: String
    var value: String
    var systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.white)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.72))
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }
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
        .shadow(color: FleetPalette.accent.opacity(0.10), radius: 16, x: 0, y: 9)
    }
}

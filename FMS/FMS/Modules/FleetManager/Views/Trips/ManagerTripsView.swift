import SwiftUI

struct ManagerTripGroup: Identifiable {
    var id: String { title }
    var title: String
    var trips: [Trip]
}

struct ManagerTripsView: View {
    @ObservedObject var viewModel: TripManagementViewModel
    @ObservedObject var vehiclesViewModel: VehicleViewModel
    @ObservedObject var usersViewModel: UserManagementViewModel

    var openAddTrip: () -> Void

    private var groupedTrips: [ManagerTripGroup] {
        [
            ManagerTripGroup(title: "Active", trips: activeTrips),
            ManagerTripGroup(title: "Scheduled", trips: scheduledTrips),
            ManagerTripGroup(title: "Completed", trips: completedTrips)
        ]
        .filter { $0.trips.isEmpty == false }
    }

    private var activeTrips: [Trip] {
        viewModel.trips
            .filter { $0.status == .accepted || $0.status == .inProgress }
            .sorted { $0.startTime < $1.startTime }
    }

    private var scheduledTrips: [Trip] {
        viewModel.trips
            .filter { $0.status == .pending }
            .sorted { $0.startTime < $1.startTime }
    }

    private var completedTrips: [Trip] {
        viewModel.trips
            .filter { $0.status == .completed }
            .sorted { ($0.endTime ?? $0.startTime) > ($1.endTime ?? $1.startTime) }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ManagerTripListScreen(
                groups: groupedTrips,
                emptyTitle: "No active or scheduled trips",
                emptyMessage: "Use the plus button to create a trip with a vehicle and driver.",
                viewModel: viewModel,
                vehiclesViewModel: vehiclesViewModel,
                usersViewModel: usersViewModel
            )

            Button(action: openAddTrip) {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(FleetPalette.primary, in: Circle())
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 16)
        }
        .refreshable {
            await viewModel.load()
        }
    }
}

struct ManagerTripListScreen: View {
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
                    GlassPanel {
                        EmptyStateView(
                            title: emptyTitle,
                            message: emptyMessage,
                            systemImage: "road.lanes"
                        )
                    }
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
        .navigationTitle("Trips")
        .navigationBarTitleDisplayMode(.large)
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

                StatusPill(text: trip.status.title, color: FleetPalette.tripStatus(trip.status))
            }

            LazyVGrid(columns: FleetPalette.twoColumnGrid, spacing: 10) {
                TripInfoTile(
                    systemImage: "clock",
                    title: Self.compactDay.string(from: trip.startTime),
                    value: FleetManagerFormat.time.string(from: trip.startTime)
                )

                TripInfoTile(
                    systemImage: "clock",
                    title: trip.endTime.map { Self.compactDay.string(from: $0) } ?? Self.compactDay.string(from: trip.startTime),
                    value: trip.endTime.map { FleetManagerFormat.time.string(from: $0) } ?? "TBD"
                )
            }

            VStack(spacing: 10) {
                TripInfoRow(
                    systemImage: "person.fill",
                    title: driver?.displayName ?? "Driver unavailable",
                    value: driver.map { "Contact: \($0.contact)" } ?? nil
                )

                TripInfoRow(
                    systemImage: "car.fill",
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
        .shadow(color: FleetPalette.primary.opacity(0.10), radius: 16, x: 0, y: 9)
        .accessibilityElement(children: .combine)
    }

    private static let compactDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yy"
        return formatter
    }()
}

private struct TripRouteGlyph: View {
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "mappin.circle.fill")
                .font(.title2.weight(.bold))
                .foregroundStyle(FleetPalette.primary)

            VStack(spacing: 3) {
                ForEach(0..<4, id: \.self) { _ in
                    Circle()
                        .fill(FleetPalette.primary.opacity(0.62))
                        .frame(width: 4, height: 4)
                }
            }

            Image(systemName: "mappin.circle.fill")
                .font(.title2.weight(.bold))
                .foregroundStyle(FleetPalette.primary)
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
                .foregroundStyle(FleetPalette.primary)
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
                .foregroundStyle(FleetPalette.primary)
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
        .navigationTitle(isLive ? "Live Trip" : "Scheduled Trip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                TripActionMenu(trip: currentTrip, viewModel: viewModel)
            }
        }
    }

    private var routeHero: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    FleetPalette.primary.opacity(0.85),
                    FleetPalette.secondary.opacity(0.74)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 330)

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    IconBubble(systemImage: isLive ? "location.north.line.fill" : "calendar", tint: .white)
                    StatusPill(text: currentTrip.status.title, color: .white)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(isLive ? "Live route" : "Route preview")
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
                    StatusPill(text: currentTrip.status.title, color: FleetPalette.tripStatus(currentTrip.status))
                }
                InfoRow(title: "Pickup", value: currentTrip.startLocation)
                InfoRow(title: "Destination", value: currentTrip.endLocation)
                InfoRow(title: "Start", value: FleetManagerFormat.shortDateTime.string(from: currentTrip.startTime))
                InfoRow(
                    title: "End",
                    value: currentTrip.endTime.map { FleetManagerFormat.shortDateTime.string(from: $0) } ?? "Not completed"
                )
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
                        StatusPill(text: isLive ? "Assigned" : "Pending", color: isLive ? FleetPalette.success : FleetPalette.primary)
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
                                .background(FleetPalette.primary, in: Circle())
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
                Text("Vehicle")
                    .font(.title3.weight(.bold))

                if let vehicle {
                    InfoRow(title: "Number", value: vehicle.licencePlate)
                    InfoRow(title: "Model", value: "\(vehicle.year) \(vehicle.make) \(vehicle.model)")
                    InfoRow(title: "Type", value: vehicle.vehicleType.capitalized)
                    InfoRow(title: "Status", value: vehicle.status.title)
                } else {
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
                    .foregroundStyle(Color.red)
                Spacer()
                Text("\(trips.count) pending")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red)
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
                StatusPill(text: "Rejection Pending", color: .red)
            }

            if let driver {
                Label(driver.displayName, systemImage: "person.fill")
                    .font(.subheadline)
            }

            if let reason = trip.rejectionReason, !reason.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reason:")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.red)
                    Text(reason)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.05))
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
                .tint(.red)

                Button {
                    Task { await viewModel.denyRejection(for: trip) }
                } label: {
                    Label("Deny", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .padding(16)
        .background(FleetPalette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        }
        .shadow(color: FleetPalette.primary.opacity(0.10), radius: 16, x: 0, y: 9)
    }
}

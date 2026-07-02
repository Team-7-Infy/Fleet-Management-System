//
//  ManagerTripFormSheet.swift
//  FMS
//
//  Created by Veer on 26/06/26.
//


import SwiftUI
import MapKit
import Combine

struct TripPlace: Identifiable {
    let id = UUID()
    var name: String
    var address: String
    var coordinate: CLLocationCoordinate2D

    var displayName: String {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedAddress.isEmpty ? name : "\(name), \(trimmedAddress)"
    }
}

struct TripRouteEstimate {
    var route: MKRoute
    var expectedArrival: Date

    var travelTime: TimeInterval {
        route.expectedTravelTime
    }

    var distanceMeters: CLLocationDistance {
        route.distance
    }

    var durationText: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = travelTime >= 3600 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: travelTime) ?? "\(Int(travelTime / 60)) min"
    }

    var distanceText: String {
        let kilometers = distanceMeters / 1000
        return kilometers >= 10
            ? String(format: "%.0f km", kilometers)
            : String(format: "%.1f km", kilometers)
    }
}

enum TripRouteEstimator {
    static func resolvePlace(named query: String) async throws -> TripPlace? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        let response = try await MKLocalSearch(request: request).start()
        return response.mapItems.first.map(place(from:))
    }

    static func estimateRoute(from pickup: TripPlace, to destination: TripPlace, startTime: Date) async throws -> TripRouteEstimate {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: pickup.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination.coordinate))
        request.transportType = .automobile
        request.departureDate = startTime

        let response = try await MKDirections(request: request).calculate()
        guard let route = response.routes.first else {
            throw TripRouteError.routeUnavailable
        }

        return TripRouteEstimate(
            route: route,
            expectedArrival: startTime.addingTimeInterval(route.expectedTravelTime)
        )
    }

    static func place(from mapItem: MKMapItem) -> TripPlace {
        TripPlace(
            name: mapItem.name ?? "Selected place",
            address: mapItem.placemark.title ?? "",
            coordinate: mapItem.placemark.coordinate
        )
    }
}

enum TripRouteError: LocalizedError {
    case routeUnavailable

    var errorDescription: String? {
        "Route estimate is unavailable for these places."
    }
}

private enum TripPlaceField: Identifiable {
    case pickup
    case destination

    var id: String {
        switch self {
        case .pickup: return "pickup"
        case .destination: return "destination"
        }
    }

    var title: String {
        switch self {
        case .pickup: return "Pickup"
        case .destination: return "Destination"
        }
    }

    var placeholder: String {
        switch self {
        case .pickup: return "Starting point"
        case .destination: return "Destination"
        }
    }
}

struct ManagerTripFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TripManagementViewModel
    @ObservedObject var vehiclesViewModel: VehicleViewModel
    @ObservedObject var usersViewModel: UserManagementViewModel
    @State private var form = FleetManagerTripForm()
    @State private var minimumStartTime = Date()
    @State private var selectedPickup: TripPlace?
    @State private var selectedDestination: TripPlace?
    @State private var routeEstimate: TripRouteEstimate?
    @State private var routeMessage: String?
    @State private var pickingPlace: TripPlaceField?
    @State private var isCalculatingRoute = false

    private var hasRegisteredDriver: Bool {
        usersViewModel.drivers.contains { $0.status == .active }
    }

    private var availableDrivers: [Driver] {
        usersViewModel.drivers.filter { $0.status == .active }
    }

    private var availableVehicles: [Vehicle] {
        vehiclesViewModel.vehicles.filter { $0.status == .active }
    }

    private var selectedVehicleTitle: String? {
        guard let vehicle = vehiclesViewModel.vehicle(for: form.vehicleId) else { return nil }
        return "\(vehicle.licencePlate) - \(vehicle.make) \(vehicle.model)"
    }

    private var selectedDriverTitle: String? {
        guard let driver = usersViewModel.driver(for: form.driverId) else { return nil }
        let user = usersViewModel.user(for: driver.userId)
        return user?.displayName ?? driver.licenceNum
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if vehiclesViewModel.vehicles.isEmpty || hasRegisteredDriver == false {
                    GlassPanel {
                        EmptyStateView(
                            title: "Trip setup needs fleet data",
                            message: "Add at least one active vehicle and one active driver before creating trips.",
                            systemImage: "point.topleft.down.curvedto.point.bottomright.up"
                        )
                    }
                } else {
                    TripPlaceButton(
                        title: "Pickup",
                        value: selectedPickup?.displayName ?? form.startLocation,
                        placeholder: "Starting point",
                        systemImage: "mappin.circle.fill"
                    ) {
                        pickingPlace = .pickup
                    }

                    TripPlaceButton(
                        title: "Destination",
                        value: selectedDestination?.displayName ?? form.endLocation,
                        placeholder: "Destination",
                        systemImage: "mappin.and.ellipse.circle.fill"
                    ) {
                        pickingPlace = .destination
                    }

                    TripRouteSelectionMap(
                        pickup: selectedPickup,
                        destination: selectedDestination,
                        route: routeEstimate?.route
                    )

                    if isCalculatingRoute {
                        Label("Calculating route", systemImage: "clock.arrow.circlepath")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(FleetPalette.accent)
                    } else if let routeEstimate {
                        TripRouteEstimateCard(estimate: routeEstimate)
                    } else if let routeMessage {
                        Label(routeMessage, systemImage: "exclamationmark.triangle")
                            .font(.subheadline)
                            .foregroundStyle(FleetPalette.warning)
                    }

                    Picker(selection: $form.vehicleId) {
                        Text("Select vehicle").tag(Optional<UUID>.none)
                        ForEach(availableVehicles) { vehicle in
                            Text("\(vehicle.licencePlate) - \(vehicle.make) \(vehicle.model)")
                                .tag(Optional(vehicle.id))
                        }
                    } label: {
                        TripSelectionMenuLabel(
                            title: "Vehicle",
                            value: selectedVehicleTitle,
                            placeholder: "Select vehicle",
                            systemImage: "car.fill"
                        )
                    }
                    .pickerStyle(.menu)
                    .tint(FleetPalette.accent)
                    .fleetField()

                    Picker(selection: $form.driverId) {
                        Text("Select user").tag(Optional<UUID>.none)
                        ForEach(availableDrivers) { driver in
                            let user = usersViewModel.user(for: driver.userId)
                            Text(user?.displayName ?? driver.licenceNum)
                                .tag(Optional(driver.id))
                        }
                    } label: {
                        TripSelectionMenuLabel(
                            title: "User",
                            value: selectedDriverTitle,
                            placeholder: "Select user",
                            systemImage: "person.fill"
                        )
                    }
                    .pickerStyle(.menu)
                    .tint(FleetPalette.accent)
                    .fleetField()

                    DatePicker("Start", selection: $form.startTime, in: minimumStartTime...)
                        .fleetField()

                    DatePicker(
                        routeEstimate == nil ? "Expected End" : "ETA",
                        selection: Binding(
                            get: { form.endTime ?? form.startTime.addingTimeInterval(3600) },
                            set: { form.endTime = $0 }
                        ),
                        in: form.startTime...
                    )
                    .fleetField()

                    FeedbackView(success: viewModel.successMessage, error: viewModel.errorMessage)

                    Button {
                        Task {
                            if await viewModel.createTrip(form: form) {
                                await vehiclesViewModel.load()
                                dismiss()
                            }
                        }
                    } label: {
                        Label("Create Trip", systemImage: "wand.and.stars")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(FleetPalette.accent)
                    .disabled(form.isValid == false)
                }
            }
            .padding()
        }
        .fleetScreenBackground()
        .navigationTitle("Create Trip")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $pickingPlace) { field in
            NavigationStack {
                TripPlacePickerSheet(field: field) { place in
                    apply(place: place, to: field)
                    pickingPlace = nil
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            minimumStartTime = Date()
            if form.startTime < minimumStartTime {
                form.startTime = minimumStartTime
            }
            if let endTime = form.endTime, endTime < form.startTime {
                form.endTime = form.startTime.addingTimeInterval(3600)
            }
            form.vehicleId = form.vehicleId ?? availableVehicles.first?.id
            form.driverId = form.driverId ?? availableDrivers.first?.id
        }
        .onChange(of: form.startTime) { _, newValue in
            if newValue < minimumStartTime {
                form.startTime = minimumStartTime
            }
            if (form.endTime ?? newValue) < newValue {
                form.endTime = newValue.addingTimeInterval(3600)
            }
            Task {
                await calculateRouteIfPossible()
            }
        }
    }

    private func apply(place: TripPlace, to field: TripPlaceField) {
        switch field {
        case .pickup:
            selectedPickup = place
            form.startLocation = place.displayName
        case .destination:
            selectedDestination = place
            form.endLocation = place.displayName
        }

        Task {
            await calculateRouteIfPossible()
        }
    }

    @MainActor
    private func calculateRouteIfPossible() async {
        guard let selectedPickup, let selectedDestination else {
            routeEstimate = nil
            routeMessage = nil
            return
        }

        isCalculatingRoute = true
        defer { isCalculatingRoute = false }

        do {
            let estimate = try await TripRouteEstimator.estimateRoute(
                from: selectedPickup,
                to: selectedDestination,
                startTime: form.startTime
            )
            routeEstimate = estimate
            routeMessage = nil
            form.endTime = estimate.expectedArrival
        } catch {
            routeEstimate = nil
            routeMessage = error.localizedDescription
        }
    }
}

private struct TripSelectionMenuLabel: View {
    var title: String
    var value: String?
    var placeholder: String
    var systemImage: String

    private var displayedValue: String {
        let trimmedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedValue.isEmpty ? placeholder : trimmedValue
    }

    private var hasValue: Bool {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var body: some View {
        HStack(spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(FleetPalette.textPrimary)

            Spacer(minLength: 8)

            Text(displayedValue)
                .font(.body)
                .foregroundStyle(hasValue ? FleetPalette.textSecondary : FleetPalette.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Image(systemName: "chevron.up.chevron.down")
                .font(.caption.weight(.bold))
                .foregroundStyle(FleetPalette.accent)
        }
        .contentShape(Rectangle())
    }
}

private struct TripPlaceButton: View {
    var title: String
    var value: String
    var placeholder: String
    var systemImage: String
    var action: () -> Void

    private var displayedValue: String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? placeholder : trimmed
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(FleetPalette.accent)
                    .frame(width: 32, height: 32)
                    .background(FleetPalette.softBlue, in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(FleetPalette.textSecondary)
                    Text(displayedValue)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? FleetPalette.textSecondary : FleetPalette.textPrimary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(FleetPalette.accent)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 66)
            .background(FleetPalette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(FleetPalette.tertiary.opacity(0.70), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct TripRouteSelectionMap: View {
    var pickup: TripPlace?
    var destination: TripPlace?
    var route: MKRoute?
    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $position) {
            if let route {
                MapPolyline(route.polyline)
                    .stroke(FleetPalette.accent, lineWidth: 5)
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
        .frame(height: 190)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(FleetPalette.tertiary.opacity(0.70), lineWidth: 1)
        }
        .overlay {
            if pickup == nil && destination == nil {
                VStack(spacing: 8) {
                    Image(systemName: "map")
                        .font(.title2.weight(.semibold))
                    Text("Select pickup and destination")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(FleetPalette.textSecondary)
                .padding()
                .background(.ultraThinMaterial, in: Capsule())
            }
        }
    }
}

private struct TripRouteEstimateCard: View {
    var estimate: TripRouteEstimate

    var body: some View {
        HStack(spacing: 12) {
            RouteEstimateItem(title: "Travel time", value: estimate.durationText, systemImage: "clock")
            RouteEstimateItem(title: "Distance", value: estimate.distanceText, systemImage: "road.lanes")
            RouteEstimateItem(title: "ETA", value: FleetManagerFormat.time.string(from: estimate.expectedArrival), systemImage: "flag.checkered")
        }
        .padding(14)
        .background(FleetPalette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(FleetPalette.tertiary.opacity(0.70), lineWidth: 1)
        }
    }
}

private struct RouteEstimateItem: View {
    var title: String
    var value: String
    var systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(FleetPalette.accent)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(FleetPalette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(FleetPalette.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TripPlacePickerSheet: View {
    var field: TripPlaceField
    var onSelect: (TripPlace) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var search = TripPlaceSearchViewModel()
    @State private var isResolving = false

    var body: some View {
        VStack(spacing: 14) {
            TextField(field.placeholder, text: $search.query)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .fleetField()
                .padding(.horizontal)

            if isResolving {
                ProgressView("Finding place")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if search.results.isEmpty {
                EmptyStateView(
                    title: "Search for a place",
                    message: "Enter a city, depot, warehouse, landmark, or full address.",
                    systemImage: "magnifyingglass"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List(search.results, id: \.self) { completion in
                    Button {
                        Task {
                            await resolve(completion)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(completion.title)
                                .font(.headline)
                                .foregroundStyle(FleetPalette.textPrimary)
                            if completion.subtitle.isEmpty == false {
                                Text(completion.subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(FleetPalette.textSecondary)
                            }
                        }
                        .padding(.vertical, 5)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Select \(field.title)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }

    @MainActor
    private func resolve(_ completion: MKLocalSearchCompletion) async {
        isResolving = true
        defer { isResolving = false }

        do {
            if let place = try await search.place(for: completion) {
                onSelect(place)
                dismiss()
            }
        } catch {
            search.errorMessage = error.localizedDescription
        }
    }
}

private final class TripPlaceSearchViewModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var query = "" {
        didSet {
            completer.queryFragment = query
        }
    }
    @Published var results: [MKLocalSearchCompletion] = []
    @Published var errorMessage: String?

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.resultTypes = [.address, .pointOfInterest]
        completer.delegate = self
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.results = completer.results
            self.errorMessage = nil
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.errorMessage = error.localizedDescription
        }
    }

    func place(for completion: MKLocalSearchCompletion) async throws -> TripPlace? {
        let request = MKLocalSearch.Request(completion: completion)
        let response = try await MKLocalSearch(request: request).start()
        return response.mapItems.first.map(TripRouteEstimator.place(from:))
    }
}

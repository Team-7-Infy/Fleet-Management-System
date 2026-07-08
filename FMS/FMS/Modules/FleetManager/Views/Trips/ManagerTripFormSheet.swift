//
//  ManagerTripFormSheet.swift
//  FMS
//
//  Created by Veer on 26/06/26.
//


import SwiftUI
import MapKit
import Combine
import CoreLocation

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

    private static let vehicleTypes = ["car", "van", "truck", "bus"]

    private var availableVehicles: [Vehicle] {
        guard form.vehicleTypeRequested.isEmpty == false else { return [] }
        let all = vehiclesViewModel.vehicles.filter {
            $0.vehicleType.lowercased() == form.vehicleTypeRequested.lowercased() &&
            ($0.status == .available || $0.status == .assigned)
        }
        let tripEnd = form.endTime ?? form.startTime.addingTimeInterval(7200)
        return all.filter { vehicle in
            let vehicleTrips = viewModel.trips.filter { $0.vehicleId == vehicle.id }
            return viewModel.hasNoOverlap(vehicleTrips, tripStart: form.startTime, tripEnd: tripEnd)
        }
    }

    private var availableDrivers: [Driver] {
        let typeToFilter: String
        if let selectedVehicleId = form.selectedVehicleId,
           let vehicle = vehiclesViewModel.vehicles.first(where: { $0.id == selectedVehicleId }) {
            typeToFilter = vehicle.vehicleType
        } else {
            typeToFilter = form.vehicleTypeRequested
        }
        
        guard typeToFilter.isEmpty == false else { return [] }
        let activeUserIds = Set(usersViewModel.users.filter { $0.isActive && $0.deletedAt == nil }.map(\.id))
        
        let matchingDrivers = usersViewModel.drivers.filter { driver in
            driver.status != .unavailable && driver.status != .inactive &&
            driver.vehicleType.lowercased() == typeToFilter.lowercased() &&
            activeUserIds.contains(driver.userId)
        }
        
        let tripEnd = form.endTime ?? form.startTime.addingTimeInterval(7200)
        
        return matchingDrivers.filter { driver in
            let driverTrips = viewModel.trips.filter { $0.driverId == driver.id }
            return viewModel.hasNoOverlap(driverTrips, tripStart: form.startTime, tripEnd: tripEnd)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Prominent Map at the top (Uber-like full-bleed style)
                TripRouteSelectionMap(
                    pickup: selectedPickup,
                    destination: selectedDestination,
                    route: routeEstimate?.route
                )

                // Uber-like Pickup & Destination vertical connection block
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(FleetPalette.success)
                            .frame(width: 8, height: 8)
                        
                        Button {
                            pickingPlace = .pickup
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("PICKUP LOCATION")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(FleetPalette.textSecondary)
                                Text(selectedPickup?.displayName ?? (form.startLocation.isEmpty ? "Starting point" : form.startLocation))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(form.startLocation.isEmpty ? FleetPalette.textTertiary : FleetPalette.textPrimary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.vertical, 12)
                    
                    HStack(spacing: 12) {
                        VStack {
                            Rectangle()
                                .fill(FleetPalette.tertiary.opacity(0.3))
                                .frame(width: 1, height: 16)
                        }
                        .frame(width: 8)
                        
                        Divider()
                    }
                    
                    HStack(spacing: 12) {
                        Rectangle()
                            .fill(FleetPalette.accent)
                            .frame(width: 8, height: 8)
                        
                        Button {
                            pickingPlace = .destination
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("DROP LOCATION")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(FleetPalette.textSecondary)
                                Text(selectedDestination?.displayName ?? (form.endLocation.isEmpty ? "Destination address" : form.endLocation))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(form.endLocation.isEmpty ? FleetPalette.textTertiary : FleetPalette.textPrimary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.vertical, 12)
                }
                .padding(.horizontal, 16)
                .background(FleetPalette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(FleetPalette.tertiary.opacity(0.08), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)

                // Loading route calculations or metrics
                if isCalculatingRoute {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Calculating optimal route...")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(FleetPalette.accent)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 4)
                } else if let routeEstimate {
                    TripRouteEstimateCard(estimate: routeEstimate)
                } else if let routeMessage {
                    Label(routeMessage, systemImage: "exclamationmark.triangle")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(FleetPalette.warning)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 4)
                }

                // Vehicle Class & Assignment Container Card
                FitnessCategoryCard {
                    VStack(spacing: 14) {
                        Picker(selection: $form.vehicleTypeRequested) {
                            Text("Any Type").tag("")
                            ForEach(Self.vehicleTypes, id: \.self) { type in
                                Text(type.capitalized).tag(type)
                            }
                        } label: {
                            TripSelectionMenuLabel(
                                title: "Vehicle Class",
                                value: form.vehicleTypeRequested.isEmpty ? nil : form.vehicleTypeRequested.capitalized,
                                placeholder: "Any type",
                                systemImage: "car.fill"
                            )
                        }
                        .pickerStyle(.menu)
                        .tint(FleetPalette.accent)

                        Divider()

                        Toggle("Auto Assign Best Driver", isOn: $form.isAutoAssign)
                            .font(.body.weight(.semibold))
                            .toggleStyle(SwitchToggleStyle(tint: FleetPalette.accent))

                        if !form.isAutoAssign {
                            Divider()

                            Picker(selection: $form.selectedVehicleId) {
                                Text("Choose Vehicle").tag(Optional<UUID>.none)
                                ForEach(availableVehicles) { vehicle in
                                    Text(vehicle.licencePlate).tag(Optional(vehicle.id))
                                }
                            } label: {
                                TripSelectionMenuLabel(
                                    title: "Assign Vehicle",
                                    value: availableVehicles.first(where: { $0.id == form.selectedVehicleId })?.licencePlate,
                                    placeholder: "Choose vehicle",
                                    systemImage: "bus.fill"
                                )
                            }
                            .pickerStyle(.menu)
                            .tint(FleetPalette.accent)

                            Divider()

                            Picker(selection: $form.selectedDriverId) {
                                Text("Choose Driver").tag(Optional<UUID>.none)
                                ForEach(availableDrivers) { driver in
                                    let user = usersViewModel.user(for: driver.userId)
                                    let uidPrefix = String(driver.id.uuidString.prefix(8))
                                    Text("\(user?.displayName ?? "Driver") (\(uidPrefix))").tag(Optional(driver.id))
                                }
                            } label: {
                                TripSelectionMenuLabel(
                                    title: "Assign Driver",
                                    value: form.selectedDriverId.flatMap { dId in
                                        let driver = usersViewModel.drivers.first(where: { $0.id == dId })
                                        let user = driver.flatMap { usersViewModel.user(for: $0.userId) }
                                        let uidPrefix = String(dId.uuidString.prefix(8))
                                        return "\(user?.displayName ?? "Driver") (\(uidPrefix))"
                                    },
                                    placeholder: "Choose driver",
                                    systemImage: "person.fill"
                                )
                            }
                            .pickerStyle(.menu)
                            .tint(FleetPalette.accent)
                        }
                    }
                }

                // Schedule Timing Picker Card
                FitnessCategoryCard {
                    VStack(spacing: 14) {
                        DatePicker("Schedule Start Time", selection: $form.startTime, in: minimumStartTime...)
                            .font(.body.weight(.semibold))

                        Divider()

                        DatePicker(
                            routeEstimate == nil ? "Expected End Time" : "Estimated Arrival (ETA)",
                            selection: Binding(
                                get: { form.endTime ?? form.startTime.addingTimeInterval(3600) },
                                set: { form.endTime = $0 }
                            ),
                            in: form.startTime...
                        )
                        .font(.body.weight(.semibold))
                    }
                }

                FeedbackView(success: viewModel.successMessage, error: viewModel.errorMessage)

                Button {
                    Task {
                        if await viewModel.createTrip(form: form) {
                            dismiss()
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "wand.and.stars")
                        Text("Confirm & Create Trip")
                            .bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(form.isValid ? FleetPalette.accent : FleetPalette.neutral.opacity(0.3), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundColor(form.isValid ? .white : FleetPalette.textTertiary)
                }
                .buttonStyle(.plain)
                .disabled(form.isValid == false)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
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
        .onChange(of: form.vehicleTypeRequested) { _, _ in
            form.selectedVehicleId = nil
            form.selectedDriverId = nil
        }
        .onChange(of: form.isAutoAssign) { _, _ in
            form.selectedVehicleId = nil
            form.selectedDriverId = nil
        }
        .onChange(of: form.selectedVehicleId) { _, _ in
            form.selectedDriverId = nil
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
        .frame(height: 260)
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
    @State private var resolvedPlace: TripPlace? = nil
    @State private var mapPosition: MapCameraPosition = .automatic

    var body: some View {
        VStack(spacing: 14) {
            TextField(field.placeholder, text: $search.query)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .fleetField()
                .padding(.horizontal)

            if isResolving {
                ProgressView("Finding place...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let place = resolvedPlace {
                VStack(spacing: 14) {
                    MapReader { proxy in
                        Map(position: $mapPosition) {
                            Marker(place.name, systemImage: "mappin.circle.fill", coordinate: place.coordinate)
                                .tint(FleetPalette.accent)
                        }
                        .frame(height: 230)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(FleetPalette.tertiary.opacity(0.12), lineWidth: 1)
                        }
                        .onTapGesture { position in
                            if let coordinate = proxy.convert(position, from: .local) {
                                Task {
                                    await updateCoordinates(coordinate)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    Text("Tap anywhere on the map to adjust the pin precisely")
                        .font(.caption)
                        .foregroundStyle(FleetPalette.textSecondary)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.title3)
                                .foregroundStyle(FleetPalette.accent)
                                .frame(width: 36, height: 36)
                                .background(FleetPalette.accent.opacity(0.08), in: Circle())
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(place.name)
                                    .font(.headline)
                                    .foregroundStyle(FleetPalette.textPrimary)
                                    .lineLimit(1)
                                if place.address.isEmpty == false {
                                    Text(place.address)
                                        .font(.subheadline)
                                        .foregroundStyle(FleetPalette.textSecondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(FleetPalette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(FleetPalette.tertiary.opacity(0.08), lineWidth: 1)
                        }
                        .padding(.horizontal)
                    }

                    Spacer()

                    Button {
                        onSelect(place)
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Confirm Location")
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(FleetPalette.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                }
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
        .onChange(of: search.query) { _, _ in
            resolvedPlace = nil
        }
    }

    @MainActor
    private func resolve(_ completion: MKLocalSearchCompletion) async {
        isResolving = true
        defer { isResolving = false }

        do {
            if let place = try await search.place(for: completion) {
                resolvedPlace = place
                mapPosition = .region(MKCoordinateRegion(
                    center: place.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
                ))
            }
        } catch {
            search.errorMessage = error.localizedDescription
        }
    }

    private func updateCoordinates(_ coordinate: CLLocationCoordinate2D) async {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                let name = placemark.name ?? placemark.thoroughfare ?? "Selected Location"
                let subLocality = placemark.subLocality ?? ""
                let locality = placemark.locality ?? ""
                let addressParts = [subLocality, locality].filter { !$0.isEmpty }
                let address = addressParts.isEmpty ? (placemark.name ?? "") : addressParts.joined(separator: ", ")
                
                await MainActor.run {
                    resolvedPlace = TripPlace(
                        name: name,
                        address: address,
                        coordinate: coordinate
                    )
                }
            } else {
                await MainActor.run {
                    resolvedPlace = TripPlace(
                        name: "Custom Location",
                        address: String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude),
                        coordinate: coordinate
                    )
                }
            }
        } catch {
            await MainActor.run {
                resolvedPlace = TripPlace(
                    name: "Custom Location",
                    address: String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude),
                    coordinate: coordinate
                )
            }
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

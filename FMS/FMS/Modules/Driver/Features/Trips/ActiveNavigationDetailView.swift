//
//  ActiveNavigationDetailView.swift
//  FMSD
//
//  Created by Dev Jain on 26/06/26.
//

import SwiftUI
import MapKit
import CoreLocation
import UIKit
import Combine

// MARK: - Haptic Feedback Manager
struct HapticManager {
    static let shared = HapticManager()
    
    func triggerImpact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func triggerNotification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}

// MARK: - MKMultiPoint Coordinates Extension
extension MKMultiPoint {
    var coordinates: [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}

// MARK: - Live Navigation View Model
class LiveNavigationViewModel: ObservableObject {
    @Published var startCoordinate: CLLocationCoordinate2D
    @Published var endCoordinate: CLLocationCoordinate2D
    @Published var destinationName: String
    @Published var routeCoordinates: [CLLocationCoordinate2D] = []
    @Published var waypoints: [RouteWaypoint] = []
    
    var geofencePolygonCoordinates: [CLLocationCoordinate2D] {
        guard routeCoordinates.count >= 2 else { return [] }
        
        // 1. Filter coordinate points to ensure consecutive points are at least 80 meters apart.
        // This removes GPS micro-noise, redundant points, and avoids extreme directional flips.
        var coords: [CLLocationCoordinate2D] = []
        for coord in routeCoordinates {
            if let last = coords.last {
                let dist = CLLocation(latitude: last.latitude, longitude: last.longitude)
                    .distance(from: CLLocation(latitude: coord.latitude, longitude: coord.longitude))
                if dist >= 80 {
                    coords.append(coord)
                }
            } else {
                coords.append(coord)
            }
        }
        if let last = routeCoordinates.last, coords.last?.latitude != last.latitude || coords.last?.longitude != last.longitude {
            coords.append(last)
        }
        
        guard coords.count >= 2 else { return [] }
        
        var leftCoords: [CLLocationCoordinate2D] = []
        var rightCoords: [CLLocationCoordinate2D] = []
        let offsetDegrees: Double = 0.0027 // Approx 300 meters buffer
        
        for i in 0..<coords.count {
            let current = coords[i]
            let lat = current.latitude
            let lon = current.longitude
            
            var dx: Double = 0
            var dy: Double = 0
            
            if i == 0 {
                let next = coords[i+1]
                dx = next.latitude - lat
                dy = next.longitude - lon
            } else if i == coords.count - 1 {
                let prev = coords[i-1]
                dx = lat - prev.latitude
                dy = lon - prev.longitude
            } else {
                let prev = coords[i-1]
                let next = coords[i+1]
                dx = next.latitude - prev.latitude
                dy = next.longitude - prev.longitude
            }
            
            let len = sqrt(dx*dx + dy*dy)
            if len > 0 {
                dx /= len
                dy /= len
            } else {
                dx = 1
                dy = 0
            }
            
            let lx = lat - dy * offsetDegrees
            let ly = lon + dx * offsetDegrees
            let rx = lat + dy * offsetDegrees
            let ry = lon - dx * offsetDegrees
            
            leftCoords.append(CLLocationCoordinate2D(latitude: lx, longitude: ly))
            rightCoords.append(CLLocationCoordinate2D(latitude: rx, longitude: ry))
        }
        
        return leftCoords + rightCoords.reversed()
    }
    
    @Published var distanceCovered: String = "120 km"
    @Published var distanceRemaining: String = "45 km"
    @Published var eta: String = "14:30 PM"
    
    let tripId: String
    let services: AppServices
    let startLocationString: String
    let endLocationString: String
    private var cancellables = Set<AnyCancellable>()
    
    init(tripId: String, services: AppServices, startLocation: String, endLocation: String) {
        self.tripId = tripId
        self.services = services
        self.startLocationString = startLocation
        self.endLocationString = endLocation
        self.destinationName = endLocation
        
        // Sensible fallbacks
        self.startCoordinate = CLLocationCoordinate2D(latitude: 12.9716, longitude: 77.5946)
        self.endCoordinate = CLLocationCoordinate2D(latitude: 12.4244, longitude: 75.7382)
        
        geocodeAndCalculateRoute()
        
        Task { @MainActor in
            await fetchWaypoints()
        }
    }
    
    func geocodeAndCalculateRoute() {
        Task {
            do {
                let startCoords = try await geocode(address: startLocationString)
                let endCoords = try await geocode(address: endLocationString)
                
                await MainActor.run {
                    self.startCoordinate = startCoords
                    self.endCoordinate = endCoords
                    self.calculateRoute()
                }
            } catch {
                print("Failed to geocode address strings: \(error). Using fallbacks.")
                await MainActor.run {
                    self.calculateRoute()
                }
            }
        }
    }
    
    private func geocode(address: String) async throws -> CLLocationCoordinate2D {
        try await withCheckedThrowingContinuation { continuation in
            CLGeocoder().geocodeAddressString(address) { placemarks, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let coord = placemarks?.first?.location?.coordinate {
                    continuation.resume(returning: coord)
                } else {
                    continuation.resume(throwing: NSError(domain: "Geocoding", code: -1, userInfo: [NSLocalizedDescriptionKey: "No coordinate found"]))
                }
            }
        }
    }
    
    func fetchWaypoints() async {
        guard let tripUUID = UUID(uuidString: tripId) else { return }
        do {
            let fetched = try await services.tripService.fetchRouteWaypoints(tripId: tripUUID)
            if !fetched.isEmpty {
                self.waypoints = fetched
                destinationName = "Surat Port Authority"
            } else {
                destinationName = "Surat Port Authority"
            }
        } catch {
            print("Failed to fetch waypoints: \(error)")
        }
    }
    
    func calculateRoute() {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: startCoordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: endCoordinate))
        request.transportType = .automobile
        
        let directions = MKDirections(request: request)
        directions.calculate { [weak self] response, error in
            guard let self = self, let route = response?.routes.first else { return }
            
            DispatchQueue.main.async {
                self.routeCoordinates = route.polyline.coordinates
                
                let remainingDistanceKm = route.distance / 1000.0
                self.distanceRemaining = String(format: "%.1f km", remainingDistanceKm)
                
                let etaDate = Date().addingTimeInterval(route.expectedTravelTime)
                let timeFormatter = DateFormatter()
                timeFormatter.timeStyle = .short
                self.eta = timeFormatter.string(from: etaDate)
                
                if self.waypoints.isEmpty {
                    self.generateWaypointsFromPolyline()
                }
            }
        }
    }
    
    func generateWaypointsFromPolyline() {
        guard !routeCoordinates.isEmpty, let tripUUID = UUID(uuidString: tripId) else { return }
        var sampledWaypoints: [RouteWaypoint] = []
        let strideValue = max(1, routeCoordinates.count / 15)
        var sequence = 1
        for i in stride(from: 0, to: routeCoordinates.count, by: strideValue) {
            let coord = routeCoordinates[i]
            sampledWaypoints.append(
                RouteWaypoint(
                    id: UUID(),
                    tripId: tripUUID,
                    latitude: coord.latitude,
                    longitude: coord.longitude,
                    bufferRadius: 300.0,
                    sequenceOrder: sequence
                )
            )
            sequence += 1
        }
        if let lastCoord = routeCoordinates.last, sequence <= 15 {
            sampledWaypoints.append(
                RouteWaypoint(
                    id: UUID(),
                    tripId: tripUUID,
                    latitude: lastCoord.latitude,
                    longitude: lastCoord.longitude,
                    bufferRadius: 300.0,
                    sequenceOrder: sequence
                )
            )
        }
        self.waypoints = sampledWaypoints
        Task {
            do {
                let saved = try await services.tripService.persistRouteWaypoints(sampledWaypoints)
                await MainActor.run { self.waypoints = saved }
            } catch {
                print("Failed to persist waypoints: \(error)")
            }
        }
    }
    
    func updateDestination(coordinate: CLLocationCoordinate2D, name: String) {
        self.endCoordinate = coordinate
        self.destinationName = name
        calculateRoute()
    }
}

// MARK: - Active Navigation Detail View
struct ActiveNavigationDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var localStore: LocalDataStore
    @EnvironmentObject var locationService: LocationManager
    
    let services: AppServices
    let user: User
    let driver: Driver?
    let trip: Trip
    let vehicles: [Vehicle]
    let onBack: () -> Void
    
    // ViewModel state
    @StateObject private var viewModel: LiveNavigationViewModel
    
    // GPS Heading Position Tracker (iOS 17+)
    @State private var cameraPosition: MapCameraPosition = .userLocation(followsHeading: true, fallback: .automatic)
    
    // Cancellation Flow States
    @State private var showingCancelSheet = false
    @State private var cancelReason = ""
    @State private var cancelComments = ""
    @State private var didConfirmCancel = false
    @State private var cancelSlideProgress: CGFloat = 0.0
    
    // End Trip Flow States
    @State private var showingEndConfirmation = false
    @State private var showingPostTripInspection = false
    @State private var postTripInspectionSubmitted = false
    @State private var showingTripSuccess = false
    @State private var finalDistance: Double = 0.0
    @State private var finalDuration: Int = 0
    @State private var finalEarnings: Double = 0.0
    
    // General SOS alerts
    @State private var showingSOSAlert = false
    
    // Track last location used for route calculation (throttling MKDirections)
    @State private var lastCalculatedLocation: CLLocation? = nil
    
    // Trip transit and pause controls
    @State private var isTripStopped = false
    @State private var showingFuelSheet = false
    
    // Map tracking locks
    @State private var isTrackingVehicle = true
    @State private var zoomMeters: Double = 600.0
    
    // Sliding bottom sheet state variables
    @State private var sheetOffset: CGFloat = 0.0
    @State private var lastOffset: CGFloat = 0.0
    @State private var isExpanded = false
    @State private var liveDistanceRemaining: String? = nil
    
    private var assignedVehicle: String {
        vehicles.first(where: { $0.id == trip.vehicleId })?.licencePlate ?? ""
    }
    
    private var vehicleIconName: String {
        let type = vehicles.first(where: { $0.id == trip.vehicleId })?.vehicleType.lowercased() ?? ""
        if type.contains("truck") {
            return "truck.box.fill"
        } else if type.contains("bus") {
            return "bus.fill"
        } else if type.contains("van") {
            return "car.side.fill"
        } else {
            return "car.fill"
        }
    }
    
    init(services: AppServices, user: User, driver: Driver?, trip: Trip, vehicles: [Vehicle], onBack: @escaping () -> Void) {
        self.services = services
        self.user = user
        self.driver = driver
        self.trip = trip
        self.vehicles = vehicles
        self.onBack = onBack
        
        _viewModel = StateObject(wrappedValue: LiveNavigationViewModel(
            tripId: trip.id.uuidString,
            services: services,
            startLocation: trip.startLocation,
            endLocation: trip.endLocation
        ))
    }
    
    var startCoordinate: CLLocationCoordinate2D {
        locationService.location?.coordinate ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    }
    
    func focusOnDriverAndRoute() {
        isTrackingVehicle = true
        let center = locationService.location?.coordinate ?? viewModel.startCoordinate
        let region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: zoomMeters,
            longitudinalMeters: zoomMeters
        )
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            cameraPosition = .region(region)
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            
            // 1. Live iOS 17+ Map View
            Map(position: $cameraPosition) {
                let currentPosition = locationService.location?.coordinate ?? viewModel.startCoordinate
                let nearestIdx = nearestRouteIndex(to: currentPosition, coordinates: viewModel.routeCoordinates)

                Annotation("Driver", coordinate: currentPosition, anchor: .center) {
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 40, height: 40)
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)

                        Circle()
                            .stroke(Color.white, lineWidth: 2.5)
                            .frame(width: 40, height: 40)

                        Image(systemName: vehicleIconName)
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .bold))
                    }
                }

                Marker(viewModel.destinationName, systemImage: "flag.checkered.circle.fill", coordinate: viewModel.endCoordinate)
                    .tint(.green)

                if !viewModel.routeCoordinates.isEmpty {
                    // Geofence Corridor corridor tracking along the entire path
                    MapPolyline(coordinates: viewModel.routeCoordinates)
                        .stroke(Color.blue.opacity(0.10), lineWidth: 60)

                    // Remaining route ahead of the driver
                    if nearestIdx < viewModel.routeCoordinates.count - 1 {
                        let remainingCoords = Array(viewModel.routeCoordinates[nearestIdx...])
                        if remainingCoords.count > 1 {
                            MapPolyline(coordinates: remainingCoords)
                                .stroke(Color.blue, lineWidth: 6)
                        }
                    }

                    // Traveled route behind the driver (dulled/grayed out)
                    if nearestIdx > 0 {
                        let traveledCoords = Array(viewModel.routeCoordinates[...nearestIdx])
                        if traveledCoords.count > 1 {
                            MapPolyline(coordinates: traveledCoords)
                                .stroke(Color.gray.opacity(0.55), lineWidth: 6)
                        }
                    }
                }

                // Geofence area represented as a single closed polygon corridor
                let polygonCoords = viewModel.geofencePolygonCoordinates
                if !polygonCoords.isEmpty {
                    MapPolygon(coordinates: polygonCoords)
                        .foregroundStyle(Color.blue.opacity(0.06))
                        .stroke(Color.blue.opacity(0.18), lineWidth: 1.5)
                }
            }
            .onMapCameraChange { (context: MapCameraUpdateContext) in
                let latMeters = context.region.span.latitudeDelta * 111_000
                if latMeters > 50 {
                    zoomMeters = latMeters
                }

                if let loc = locationService.location {
                    let mapCenter = context.region.center
                    let centerLoc = CLLocation(latitude: mapCenter.latitude, longitude: mapCenter.longitude)
                    let distance = centerLoc.distance(from: loc)
                    if distance > 100 {
                        isTrackingVehicle = false
                    }
                }
            }
            .ignoresSafeArea()
            
            // 2. Floating Actions Overlay at the Top (Proceed to the route instruction banner)
            VStack {
                HStack(alignment: .top, spacing: 12) {
                    // Left Exit Button
                    Button(action: {
                        HapticManager.shared.triggerImpact(style: .light)
                        onBack()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 34))
                            .foregroundColor(.black.opacity(0.6))
                            .background(Circle().fill(Color(UIColor.systemBackground)))
                            .shadow(color: .black.opacity(0.15), radius: 6)
                    }
                    .padding(.top, 8)
                    .accessibilityLabel("Exit Navigation")
                    
                    // Navigation instructions dark grey banner
                    HStack(spacing: 16) {
                        // Custom Direction Icon: dot and arrow inside a circle
                        ZStack {
                            Circle()
                                .stroke(Color.white, lineWidth: 3.5)
                                .frame(width: 42, height: 42)
                            
                            HStack(spacing: 0) {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 6, height: 6)
                                Rectangle()
                                    .fill(Color.white)
                                    .frame(width: 12, height: 3.5)
                                Image(systemName: "triangle.fill")
                                    .resizable()
                                    .foregroundColor(.white)
                                    .frame(width: 8, height: 10)
                                    .rotationEffect(.degrees(90))
                                    .offset(x: -2)
                            }
                            .offset(x: -1)
                        }
                        .frame(width: 44, height: 44)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Proceed to")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            Text("the route")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(white: 0.22)) // Dark grey background matching Apple Maps
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.15), radius: 6)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                Spacer()
            }
            
            // 3. Floating Actions on the Right (Quick Access for Navigation, Fuel, and SOS in a vertical line)
            VStack {
                HStack {
                    Spacer()
                    VStack(spacing: 16) {
                        // 1. Re-center / Route Focus Button (Navigation)
                        Button(action: {
                            HapticManager.shared.triggerImpact(style: .medium)
                            focusOnDriverAndRoute()
                        }) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(isTrackingVehicle ? .blue : .black)
                                .frame(width: 50, height: 50)
                                .background(Circle().fill(Color.white))
                                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                        }
                        .accessibilityLabel("Re-center Map")
                        
                        // 3. Add Fuel Button
                        Button(action: {
                            HapticManager.shared.triggerImpact(style: .medium)
                            showingFuelSheet = true
                        }) {
                            Image(systemName: "fuelpump.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.blue)
                                .frame(width: 50, height: 50)
                                .background(Circle().fill(Color.white))
                                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                        }
                        .accessibilityLabel("Add Fuel")
                        .sheet(isPresented: $showingFuelSheet) {
                            NavigationStack {
                                TripFuelHistoryView(
                                    isReadOnly: false,
                                    activeTripId: viewModel.tripId,
                                    vehicleNumber: assignedVehicle,
                                    expenseService: services.expenseService,
                                    driverId: trip.driverId,
                                    vehicleId: trip.vehicleId,
                                    vehicleFuelType: nil
                                )
                                .environmentObject(localStore)
                            }
                        }
                        
                        // 4. SOS Button
                        Button(action: {
                            HapticManager.shared.triggerNotification(type: .error)
                            showingSOSAlert = true
                        }) {
                            Image(systemName: "exclamationmark.bubble.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.red)
                                .frame(width: 50, height: 50)
                                .background(Circle().fill(Color.white))
                                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                        }
                        .accessibilityLabel("Emergency SOS")
                    }
                    .padding(.trailing, 16)
                }
                .padding(.top, 100) // Positioned nicely below the top header instruction banner
                Spacer()
            }
            
            

            
            // 4. Structured Driver Journey Dashboard Panel
            VStack(spacing: 16) {
                // Drag Handle Indicator
                Capsule()
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 36, height: 5)
                    .padding(.top, 10)
                
                // 1. Bottom Bar (ETA, Distance, Speed) - ALWAYS VISIBLE
                HStack(spacing: 0) {
                    VStack(spacing: 4) {
                        Text(viewModel.eta)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("arrival")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    
                    VStack(spacing: 4) {
                        Text(liveDistanceRemaining ?? viewModel.distanceRemaining)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                        Text("remaining")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    
                    VStack(spacing: 4) {
                        Text(isTripStopped ? "0 km/h" : "65 km/h")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.blue)
                        Text("speed")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        isExpanded.toggle()
                    }
                }
                
                if isExpanded {
                    VStack(spacing: 16) {
                        Divider().padding(.horizontal)
                        
                        // Call Manager Card (instead of destination location info)
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.12))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "phone.fill")
                                    .foregroundColor(.blue)
                                    .font(.title3)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Call Manager")
                                    .fontWeight(.bold)
                                Text("Contact Dispatch Support")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                HapticManager.shared.triggerImpact(style: .medium)
                                if let url = URL(string: "tel://100") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color(UIColor.systemGray5))
                                        .frame(width: 38, height: 38)
                                    Image(systemName: "phone.fill")
                                        .foregroundColor(.blue)
                                        .font(.subheadline)
                                }
                            }
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 20).fill(Color(UIColor.secondarySystemGroupedBackground)))
                        .padding(.horizontal)
                        
                        // Pause / Resume Trip Row
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.orange.opacity(0.12))
                                    .frame(width: 44, height: 44)
                                Image(systemName: isTripStopped ? "play.fill" : "pause.fill")
                                    .foregroundColor(.orange)
                                    .font(.title3)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(isTripStopped ? "Resume Journey" : "Pause Journey")
                                    .fontWeight(.bold)
                                Text(isTripStopped ? "Start tracking telemetry" : "Temporarily halt navigation")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                HapticManager.shared.triggerImpact(style: .medium)
                                withAnimation(.spring()) {
                                    isTripStopped.toggle()
                                    UserDefaults.standard.set(isTripStopped, forKey: "trip_\(trip.id.uuidString)_paused")
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color(UIColor.systemGray5))
                                        .frame(width: 38, height: 38)
                                    Image(systemName: isTripStopped ? "play.fill" : "pause.fill")
                                        .foregroundColor(.orange)
                                        .font(.subheadline)
                                }
                            }
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 20).fill(Color(UIColor.secondarySystemGroupedBackground)))
                        .padding(.horizontal)

                        // Complete Trip Button
                        Button(action: {
                            HapticManager.shared.triggerImpact(style: .heavy)
                            let deadline = Date().addingTimeInterval(2 * 3600)
                            localStore.pendingPostTripInspection = PendingPostTripInspection(
                                tripId: trip.id.uuidString,
                                deadline: deadline
                            )
                            Task {
                                var updatedTrip = trip
                                updatedTrip.postTripInspectionDueAt = deadline
                                _ = try? await services.tripService.updateTrip(updatedTrip)
                            }
                            onBack()
                        }) {
                            Text("Complete Trip")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(Color.red)
                                .cornerRadius(18)
                                .shadow(color: Color.red.opacity(0.2), radius: 6, x: 0, y: 3)
                        }
                        .padding(.horizontal)
                        .padding(.top, 4)
                        .padding(.bottom, 8)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.bottom, isExpanded ? 0 : 20) // Add bottom padding to push content away from rounded corners!
            .background(
                RoundedRectangle(cornerRadius: 38) // Highly rounded capsule
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .light)
                    .shadow(color: Color.black.opacity(0.12), radius: 20, x: 0, y: -5)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .gesture(
                DragGesture()
                    .onEnded { value in
                        if value.translation.height < -20 {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                isExpanded = true
                            }
                        } else if value.translation.height > 20 {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                isExpanded = false
                            }
                        }
                    }
            )
            
            if showingTripSuccess {
                TripCompletionSuccessView(
                    trip: trip,
                    distance: finalDistance,
                    durationMinutes: finalDuration,
                    onDismiss: {
                        showingTripSuccess = false
                        onBack()
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(200)
            }
        }
        .toolbar(.hidden, for: .navigationBar)

        .alert(isPresented: $showingSOSAlert) {
            Alert(
                title: Text("EMERGENCY SOS"),
                message: Text("Triggering SOS will instantly broadcast your live coordinates and alert fleet dispatch."),
                primaryButton: .destructive(Text("CONFIRM EMERGENCY SOS")) {
                    Task {
                        do {
                            try await services.tripService.updateTripStatus(
                                id: trip.id,
                                status: .cancelled,
                                rejectionReason: "SOS Emergency: Automatically cancelled via emergency SOS alert during active navigation."
                            )
                            
                            // Send notification to manager instantly
                            let fmUserId = try? await services.userManagementService.fetchUsers()
                                .first(where: { $0.role == .fleetManager })?.id
                            let notification = AppNotification(
                                id: UUID(),
                                title: "CRITICAL: Driver SOS Emergency",
                                message: "Driver has triggered emergency SOS alert for Trip from \(trip.startLocation) to \(trip.endLocation) during active navigation.",
                                type: "geofence_exit",
                                isRead: false,
                                referenceId: trip.id,
                                recipientId: fmUserId,
                                createdAt: Date()
                            )
                            _ = try? await services.notificationService.createNotification(notification)
                            
                            await MainActor.run {
                                onBack()
                            }
                        } catch {
                            print("Failed to cancel trip on SOS: \(error)")
                        }
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(isPresented: $showingCancelSheet, onDismiss: {
            withAnimation(.spring()) {
                cancelSlideProgress = 0.0
            }
            if didConfirmCancel {
                HapticManager.shared.triggerNotification(type: .success)
                UserDefaults.standard.removeObject(forKey: "trip_\(trip.id.uuidString)_paused")
                Task {
                    try? await services.tripService.updateTripStatus(
                        id: trip.id,
                        status: .cancelled,
                        rejectionReason: cancelComments.isEmpty ? cancelReason : "\(cancelReason): \(cancelComments)"
                    )
                }
                onBack()
            }
        }) {
            TripCancellationView(
                isConfirmed: $didConfirmCancel,
                selectedReason: $cancelReason,
                comments: $cancelComments
            )
        }
        .onAppear {
            self.isTripStopped = UserDefaults.standard.bool(forKey: "trip_\(trip.id.uuidString)_paused")
            locationService.requestPermission()
            locationService.notificationService = services.notificationService
            locationService.userManagementService = services.userManagementService
            locationService.startTracking(
                tripId: trip.id,
                vehicleId: trip.vehicleId,
                driverId: trip.driverId,
                service: services.tripService
            )

            focusOnDriverAndRoute()
        }
        .onReceive(locationService.$location) { newLocation in
            guard let newLocation = newLocation else { return }

            lastCalculatedLocation = newLocation

            guard !isTripStopped else { return }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                cameraPosition = .userLocation(followsHeading: true, fallback: .automatic)
            }

            let nearestIdx = nearestRouteIndex(to: newLocation.coordinate, coordinates: viewModel.routeCoordinates)
            let remainingKm = calculateRemainingDistance(from: nearestIdx, coordinates: viewModel.routeCoordinates)
            liveDistanceRemaining = String(format: "%.1f km", remainingKm)
        }
        .onDisappear {
            locationService.stopTracking()
        }
        .onReceive(viewModel.$waypoints) { waypoints in
            guard !waypoints.isEmpty, let vehicleId = trip.vehicleId, let driverId = trip.driverId else { return }
            locationService.startMonitoringRoute(
                tripId: trip.id,
                vehicleId: vehicleId,
                driverId: driverId,
                waypoints: waypoints,
                service: services.tripService
            )
        }
    }
    
    private func calculateRemainingDistance(from index: Int, coordinates: [CLLocationCoordinate2D]) -> Double {
        guard index >= 0, index < coordinates.count else { return 0.0 }
        var distance: Double = 0.0
        for i in index..<(coordinates.count - 1) {
            let loc1 = CLLocation(latitude: coordinates[i].latitude, longitude: coordinates[i].longitude)
            let loc2 = CLLocation(latitude: coordinates[i+1].latitude, longitude: coordinates[i+1].longitude)
            distance += loc1.distance(from: loc2)
        }
        return distance / 1000.0
    }

    private func nearestRouteIndex(to coordinate: CLLocationCoordinate2D, coordinates: [CLLocationCoordinate2D]) -> Int {
        guard !coordinates.isEmpty else { return 0 }
        let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        var bestIdx = 0
        var bestDist = Double.greatestFiniteMagnitude
        for (i, coord) in coordinates.enumerated() {
            let loc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            let dist = target.distance(from: loc)
            if dist < bestDist {
                bestDist = dist
                bestIdx = i
            }
        }
        return bestIdx
    }
}

// MARK: - Slide to Cancel Button (Driver Safety)
struct SlideToCancel: View {
    @Binding var progress: CGFloat
    var onComplete: () -> Void
    
    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .frame(height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            LinearGradient(
                                colors: [Color.red.opacity(0.4), Color.red.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.red.opacity(0.04))
                )
            
            Text("SLIDE TO CANCEL DISPATCH")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(Color.red.opacity(0.8))
                .tracking(2.0)
                .frame(maxWidth: .infinity)
                .opacity(Double(1.0 - progress))
                .animation(.easeInOut, value: progress)
            
            HStack {
                Spacer().frame(width: progress * (UIScreen.main.bounds.width - 106))
                
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 1.0, green: 0.2, blue: 0.2), Color(red: 0.8, green: 0.0, blue: 0.0)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.red.opacity(0.4), radius: 6, x: 0, y: 3)
                    
                    Image(systemName: "chevron.right.2")
                        .font(.headline)
                        .fontWeight(.black)
                        .foregroundColor(.white)
                }
                .frame(width: 52, height: 52)
                .padding(4)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let maxSlide: CGFloat = UIScreen.main.bounds.width - 106
                            if value.translation.width > 0 && value.translation.width <= maxSlide {
                                progress = value.translation.width / maxSlide
                                if Int(value.translation.width) % 30 == 0 {
                                    HapticManager.shared.triggerImpact(style: .light)
                                }
                            }
                        }
                        .onEnded { value in
                            if progress > 0.82 {
                                HapticManager.shared.triggerNotification(type: .warning)
                                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                                    progress = 1.0
                                }
                                onComplete()
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    progress = 0.0
                                }
                            }
                        }
                )
            }
        }
        .frame(height: 60)
    }
}

// MARK: - Cancellation Modal View
struct TripCancellationView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var isConfirmed: Bool
    @Binding var selectedReason: String
    @Binding var comments: String
    
    let reasons = [
        "Vehicle Breakdown",
        "Severe Weather Conditions",
        "Medical / Health Emergency",
        "Traffic / Route Closure",
        "Wrong Route Assigned",
        "Other"
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Reason for Cancellation (Required)")) {
                    Picker("Select Reason", selection: $selectedReason) {
                        Text("Select a reason...").tag("")
                        ForEach(reasons, id: \.self) { reason in
                            Text(reason).tag(reason)
                        }
                    }
                }
                
                Section(header: Text("Additional Comments / Details")) {
                    TextEditor(text: $comments)
                        .frame(height: 100)
                }
            }
            .navigationTitle("Cancel Journey")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticManager.shared.triggerImpact(style: .light)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm Cancel") {
                        HapticManager.shared.triggerImpact(style: .medium)
                        isConfirmed = true
                        dismiss()
                    }
                    .disabled(selectedReason.isEmpty)
                    .fontWeight(.bold)
                    .foregroundColor(selectedReason.isEmpty ? .gray : .red)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .background(
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
            )
        }
    }
}

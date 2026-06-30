import Foundation
import CoreLocation
import MapKit
import Combine

@MainActor
final class TripNavigationViewModel: ObservableObject {
    @Published var route: MKRoute?
    @Published var waypoints: [RouteWaypoint] = []
    @Published var isOffRoute = false
    @Published var offRouteDistance: Double = 0
    @Published var deviationAlertMessage: String?
    @Published var isLoadingRoute = false

    let trip: Trip
    let tripService: TripServiceProtocol
    private weak var locationManager: DriverLocationManager?
    private var pollingTimer: Timer?
    private var consecutiveOffRoute = 0
    private var nearestWaypointIndex = 0

    init(
        trip: Trip,
        tripService: TripServiceProtocol,
        locationManager: DriverLocationManager
    ) {
        self.trip = trip
        self.tripService = tripService
        self.locationManager = locationManager
    }

    func loadWaypoints() async {
        do {
            waypoints = try await tripService.fetchRouteWaypoints(tripId: trip.id)
            await calculateRoute()
            startPolling()
        } catch {
            deviationAlertMessage = "Failed to load route waypoints."
        }
    }

    private func calculateRoute() async {
        guard waypoints.count >= 2 else { return }
        isLoadingRoute = true
        defer { isLoadingRoute = false }

        let coordinates = waypoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: coordinates.first!))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: coordinates.last!))
        request.transportType = .automobile

        do {
            let directions = MKDirections(request: request)
            let response = try await directions.calculate()
            route = response.routes.first
        } catch {
            deviationAlertMessage = "Failed to calculate route."
        }
    }

    private func startPolling() {
        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.checkDeviation()
            }
        }
    }

    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    private func checkDeviation() async {
        guard let location = locationManager?.currentLocation else { return }
        guard !waypoints.isEmpty else { return }

        let nearest = nearestWaypoint(to: location)
        let distance = location.distance(from: nearest.location)
        offRouteDistance = distance
        nearestWaypointIndex = nearest.index

        if distance > nearest.waypoint.bufferRadius {
            consecutiveOffRoute += 1
            if consecutiveOffRoute >= 3 {
                isOffRoute = true
                deviationAlertMessage = "Deviation detected: \(Int(distance))m from route at waypoint \(nearest.waypoint.sequenceOrder)."
                logDeviationAlert(distance: distance)
                consecutiveOffRoute = 0
            }
        } else {
            consecutiveOffRoute = 0
            isOffRoute = false
        }
    }

    private func nearestWaypoint(to location: CLLocation) -> (waypoint: RouteWaypoint, index: Int, location: CLLocation) {
        var best = waypoints[0]
        var bestIndex = 0
        var bestDistance = Double.infinity

        for (index, wp) in waypoints.enumerated() {
            let wpLocation = CLLocation(latitude: wp.latitude, longitude: wp.longitude)
            let d = location.distance(from: wpLocation)
            if d < bestDistance {
                best = wp
                bestIndex = index
                bestDistance = d
            }
        }

        return (best, bestIndex, CLLocation(latitude: best.latitude, longitude: best.longitude))
    }

    private func logDeviationAlert(distance: Double) {
        Task {
            let alert = DeviationAlert(
                id: UUID(),
                timestamp: Date(),
                distance: distance,
                vehicleId: trip.vehicleId,
                geofenceId: nil,
                tripId: trip.id
            )
            do {
                _ = try await tripService.createDeviationAlert(alert)
            } catch {
                deviationAlertMessage = "Failed to log deviation alert."
            }
        }
    }

    var region: MKCoordinateRegion {
        if let route {
            return MKCoordinateRegion(
                center: route.polyline.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }
        if let first = waypoints.first {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 12.9716, longitude: 77.5946),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
    }

    deinit {
        pollingTimer?.invalidate()
    }
}

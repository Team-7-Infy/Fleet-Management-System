import Foundation
import CoreLocation
import MapKit
import Combine

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()

    @Published var location: CLLocation?
    @Published var heading: CLHeading?
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @Published var authorizationStatus: CLAuthorizationStatus?
    @Published var isTracking: Bool = false
    @Published var waypoints: [RouteWaypoint] = []

    private var activeTripId: UUID?
    private var activeVehicleId: UUID?
    private var activeDriverId: UUID?
    private var tripService: TripServiceProtocol?
    var notificationService: NotificationServiceProtocol?
    private var lastAlertTime: Date?

    private var isStationary: Bool = false
    private var stationaryCount: Int = 0

    private let bufferLock = NSLock()
    private var _pendingTelemetryBuffer: [Telemetry] = []

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.showsBackgroundLocationIndicator = true
        locationManager.distanceFilter = 10
        locationManager.activityType = .automotiveNavigation
    }

    func requestPermission() {
        locationManager.requestAlwaysAuthorization()
    }

    func startTracking(tripId: UUID?, vehicleId: UUID?, driverId: UUID?, service: TripServiceProtocol?) {
        self.activeTripId = tripId
        self.activeVehicleId = vehicleId
        self.activeDriverId = driverId
        self.tripService = service
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
        isTracking = true
    }

    func startTracking() {
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
        isTracking = true
    }

    func stopTracking() {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
        isTracking = false
        activeTripId = nil
        activeVehicleId = nil
        activeDriverId = nil
        tripService = nil
        waypoints = []
    }

    func startMonitoringRoute(tripId: UUID, vehicleId: UUID, driverId: UUID, waypoints: [RouteWaypoint], service: TripServiceProtocol) {
        self.activeTripId = tripId
        self.activeVehicleId = vehicleId
        self.activeDriverId = driverId
        self.waypoints = waypoints
        self.tripService = service
    }

    func stopMonitoringRoute() {
        self.activeTripId = nil
        self.activeVehicleId = nil
        self.activeDriverId = nil
        self.waypoints = []
        self.tripService = nil
    }

    private func updateTrackingFrequency(speed: CLLocationSpeed) {
        if speed < 1 {
            locationManager.distanceFilter = 100
            stationaryCount += 1
            if stationaryCount > 5 { isStationary = true }
        } else if speed < 10 {
            locationManager.distanceFilter = 20
            isStationary = false
            stationaryCount = 0
        } else {
            locationManager.distanceFilter = 10
            isStationary = false
            stationaryCount = 0
        }
    }

    private var pendingTelemetryBuffer: [Telemetry] {
        get { bufferLock.withLock { _pendingTelemetryBuffer } }
        set { bufferLock.withLock { _pendingTelemetryBuffer = newValue } }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
            startTracking()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latestLocation = locations.last else { return }
        updateTrackingFrequency(speed: latestLocation.speed)
        updateLocation(latestLocation)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        DispatchQueue.main.async {
            self.heading = newHeading
        }
    }

    func updateLocation(_ newLocation: CLLocation) {
        DispatchQueue.main.async {
            self.location = newLocation
            self.region = MKCoordinateRegion(
                center: newLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }

        checkRouteDeviation(currentLocation: newLocation)
        uploadLiveTelemetry(currentLocation: newLocation)
        retryPendingTelemetry()
    }

    private func uploadLiveTelemetry(currentLocation: CLLocation) {
        guard let driverId = activeDriverId, let service = tripService else { return }

        let telemetry = Telemetry(
            id: UUID(),
            timestamp: Date(),
            speed: currentLocation.speed >= 0 ? currentLocation.speed * 3.6 : nil,
            driverId: driverId,
            latitude: currentLocation.coordinate.latitude,
            longitude: currentLocation.coordinate.longitude,
            tripId: activeTripId,
            vehicleId: activeVehicleId,
            heading: heading?.trueHeading
        )

        Task {
            do {
                _ = try await service.logTelemetry(telemetry)
            } catch {
                var buffer = pendingTelemetryBuffer
                buffer.append(telemetry)
                if buffer.count > 500 { buffer.removeFirst() }
                pendingTelemetryBuffer = buffer
            }
        }
    }

    private func retryPendingTelemetry() {
        let batch = pendingTelemetryBuffer
        guard !batch.isEmpty else { return }
        pendingTelemetryBuffer = []

        guard let service = tripService else {
            pendingTelemetryBuffer = Array(batch.prefix(500))
            return
        }

        Task {
            var failures: [Telemetry] = []
            for entry in batch {
                do {
                    _ = try await service.logTelemetry(entry)
                } catch {
                    failures.append(entry)
                    if failures.count >= 500 { break }
                }
            }
            if !failures.isEmpty {
                var buffer = pendingTelemetryBuffer
                buffer.append(contentsOf: failures)
                if buffer.count > 500 { buffer = Array(buffer.suffix(500)) }
                pendingTelemetryBuffer = buffer
            }
        }
    }

    private func checkRouteDeviation(currentLocation: CLLocation) {
        guard !waypoints.isEmpty, let tripId = activeTripId, let vehicleId = activeVehicleId, let service = tripService else { return }

        let isInsideAnyGeofence = waypoints.contains { waypoint in
            let waypointLoc = CLLocation(latitude: waypoint.latitude, longitude: waypoint.longitude)
            let distance = currentLocation.distance(from: waypointLoc)
            return distance <= waypoint.bufferRadius
        }

        if !isInsideAnyGeofence {
            let minDistance = waypoints.map { waypoint in
                let waypointLoc = CLLocation(latitude: waypoint.latitude, longitude: waypoint.longitude)
                return currentLocation.distance(from: waypointLoc)
            }.min() ?? 0.0

            triggerDeviationAlert(tripId: tripId, vehicleId: vehicleId, distance: minDistance, service: service)
        }
    }

    private func triggerDeviationAlert(tripId: UUID, vehicleId: UUID, distance: Double, service: TripServiceProtocol) {
        if let lastTime = lastAlertTime, Date().timeIntervalSince(lastTime) < 60 {
            return
        }
        lastAlertTime = Date()

        Task {
            do {
                let alert = DeviationAlert(
                    id: UUID(),
                    timestamp: Date(),
                    distance: distance,
                    vehicleId: vehicleId,
                    geofenceId: nil,
                    tripId: tripId
                )
                _ = try await service.createDeviationAlert(alert)

                if let notificationService {
                    let notification = AppNotification(
                        id: UUID(),
                        title: "Route Deviation Detected",
                        message: "Vehicle has deviated from planned route by \(String(format: "%.0f", distance)) meters.",
                        type: "geofence_exit",
                        isRead: false,
                        referenceId: tripId,
                        recipientId: nil,
                        createdAt: Date()
                    )
                    _ = try? await notificationService.createNotification(notification)
                }
            } catch {
                print("Failed to report deviation alert: \(error.localizedDescription)")
            }
        }
    }
}

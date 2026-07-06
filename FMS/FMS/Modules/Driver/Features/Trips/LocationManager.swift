//
//  LocationManager.swift
//  FMSD
//
//  Created by Dev Jain on 24/06/26.
//


import Foundation
import CoreLocation
import MapKit
import Combine

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    @Published var location: CLLocation?
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // Default fallback
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @Published var authorizationStatus: CLAuthorizationStatus?
    @Published var isTracking: Bool = false
    @Published var waypoints: [RouteWaypoint] = []
    
    private var activeTripId: UUID?
    private var activeVehicleId: UUID?
    private var activeDriverId: UUID?
    private var tripService: TripServiceProtocol?
    private var lastAlertTime: Date?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.allowsBackgroundLocationUpdates = false // Critical for fleet apps
        locationManager.pausesLocationUpdatesAutomatically = false
    }
    
    func requestPermission() {
        locationManager.requestAlwaysAuthorization()
    }
    
    func startTracking() {
        locationManager.startUpdatingLocation()
        isTracking = true
    }
    
    func stopTracking() {
        locationManager.stopUpdatingLocation()
        isTracking = false
        stopMonitoringRoute()
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
    
    // MARK: - CLLocationManagerDelegate
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
            startTracking()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latestLocation = locations.last else { return }
        updateLocation(latestLocation)
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
    }

    private func uploadLiveTelemetry(currentLocation: CLLocation) {
        guard let driverId = activeDriverId, let service = tripService else { return }
        
        Task {
            do {
                let telemetry = Telemetry(
                    id: UUID(),
                    timestamp: Date(),
                    speed: currentLocation.speed >= 0 ? currentLocation.speed * 3.6 : nil,
                    driverId: driverId,
                    latitude: currentLocation.coordinate.latitude,
                    longitude: currentLocation.coordinate.longitude
                )
                _ = try await service.logTelemetry(telemetry)
                print("Uploaded telemetry to DB: (\(telemetry.latitude), \(telemetry.longitude))")
            } catch {
                print("Failed to log live location telemetry: \(error.localizedDescription)")
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
            return // Throttle alerts to once per minute
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
                print("Successfully reported deviation alert of \(distance) meters.")
            } catch {
                print("Failed to report deviation alert: \(error.localizedDescription)")
            }
        }
    }
}

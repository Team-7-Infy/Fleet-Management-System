import SwiftUI
import MapKit

struct TripCompletionSuccessView: View {
    let trip: Trip
    let distance: Double
    let durationMinutes: Int
    let onDismiss: () -> Void
    
    @State private var animateItems = false
    
    // Route display states
    @State private var startCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    @State private var endCoordinate = CLLocationCoordinate2D(latitude: 37.8080, longitude: -122.4177)
    @State private var route: MKRoute? = nil
    @State private var position: MapCameraPosition = .automatic
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Great Job!")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundColor(.primary)
                            .scaleEffect(animateItems ? 1 : 0.8)
                            .opacity(animateItems ? 1 : 0)
                        
                        Text("You've safely completed your trip.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .opacity(animateItems ? 1 : 0)
                    }
                    .padding(.top, 40)
                    
                    // Main Journey Card
                    VStack(spacing: 20) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("DISTANCE")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                                HStack(spacing: 6) {
                                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                                        .foregroundColor(.green)
                                    Text(String(format: "%.1f miles", distance))
                                        .font(.headline)
                                        .fontWeight(.bold)
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("TIME")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                                HStack(spacing: 6) {
                                    Image(systemName: "clock")
                                        .foregroundColor(.blue)
                                    Text("\(durationMinutes) mins")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                }
                            }
                        }
                    }
                    .padding(24)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(24)
                    .shadow(color: Color.black.opacity(0.04), radius: 10, y: 5)
                    .offset(y: animateItems ? 0 : 50)
                    .opacity(animateItems ? 1 : 0)
                    
                    // Route Map Card (Enlarged and showing polyline route)
                    VStack(alignment: .leading, spacing: 12) {
                        ZStack(alignment: .bottomLeading) {
                            Map(position: $position) {
                                Marker("Start", systemImage: "play.circle.fill", coordinate: startCoordinate)
                                    .tint(.green)
                                Marker("End", systemImage: "flag.circle.fill", coordinate: endCoordinate)
                                    .tint(.red)
                                
                                if let route {
                                    MapPolyline(route.polyline)
                                        .stroke(.blue, lineWidth: 6)
                                }
                            }
                            .frame(height: 280)
                            .cornerRadius(18)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Route Map")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                            .padding(12)
                        }
                    }
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(24)
                    .shadow(color: Color.black.opacity(0.04), radius: 10, y: 5)
                    .offset(y: animateItems ? 0 : 50)
                    .opacity(animateItems ? 1 : 0)
                    
                    Spacer(minLength: 24)
                    
                    // Button: Back to Dashboard
                    Button(action: onDismiss) {
                        HStack {
                            Text("Back to Dashboard")
                                .font(.headline)
                                .fontWeight(.bold)
                            Image(systemName: "arrow.right")
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.green)
                        .cornerRadius(18)
                        .shadow(color: Color.green.opacity(0.2), radius: 8, y: 4)
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 24)
                    .offset(y: animateItems ? 0 : 50)
                    .opacity(animateItems ? 1 : 0)
                }
                .padding(.horizontal, 24)
            }
        }
        .onAppear {
            loadRoute()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0).delay(0.1)) {
                animateItems = true
            }
        }
    }
    
    private func loadRoute() {
        Task {
            do {
                let startCoords = try await geocode(address: trip.startLocation)
                let endCoords = try await geocode(address: trip.endLocation)
                
                await MainActor.run {
                    self.startCoordinate = startCoords
                    self.endCoordinate = endCoords
                    calculateRoute(from: startCoords, to: endCoords)
                }
            } catch {
                print("Failed to geocode address strings: \(error). Using fallbacks.")
                let startCoords = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
                let endCoords = CLLocationCoordinate2D(latitude: 37.8080, longitude: -122.4177)
                await MainActor.run {
                    self.startCoordinate = startCoords
                    self.endCoordinate = endCoords
                    calculateRoute(from: startCoords, to: endCoords)
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
    
    private func calculateRoute(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: end))
        request.transportType = .automobile
        
        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            if let route = response?.routes.first {
                DispatchQueue.main.async {
                    self.route = route
                    self.position = .rect(route.polyline.boundingMapRect)
                }
            }
        }
    }
}

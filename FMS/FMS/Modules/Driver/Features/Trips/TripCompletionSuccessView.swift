import SwiftUI
import MapKit
import Combine

struct ConfettiParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var color: Color
    var size: CGFloat
    var speedY: CGFloat
    var angle: Double
    var spin: Double
}

struct ConfettiEmitterView: View {
    @State private var particles: [ConfettiParticle] = []
    let timer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()
    
    let colors: [Color] = [.green, .teal, .blue, .yellow, .orange, .purple, .pink]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Rectangle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size * 0.6)
                        .rotationEffect(.degrees(particle.angle))
                        .position(x: particle.x, y: particle.y)
                }
            }
            .onAppear {
                for _ in 0..<55 {
                    particles.append(createParticle(in: geometry.size))
                }
            }
            .onReceive(timer) { _ in
                for i in 0..<particles.count {
                    particles[i].y += particles[i].speedY
                    particles[i].angle += particles[i].spin
                    
                    if particles[i].y > geometry.size.height {
                        particles[i] = createParticle(in: geometry.size, startAtTop: true)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
    
    private func createParticle(in size: CGSize, startAtTop: Bool = false) -> ConfettiParticle {
        ConfettiParticle(
            x: CGFloat.random(in: 0...size.width),
            y: startAtTop ? -10 : CGFloat.random(in: -100...size.height),
            color: colors.randomElement() ?? .green,
            size: CGFloat.random(in: 6...12),
            speedY: CGFloat.random(in: 3...7),
            angle: Double.random(in: 0...360),
            spin: Double.random(in: 2...8)
        )
    }
}

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
            AppColor.background
                .ignoresSafeArea()
            
            ConfettiEmitterView()
            
            VStack(spacing: 0) {
                // Top Left Close Button Row
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                            .padding(10)
                            .background(Circle().fill(Color(.systemGray5)))
                    }
                    .buttonStyle(PlainButtonStyle())
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // Big Tick Icon
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 76))
                            .foregroundColor(.blue) // Primary color
                            .scaleEffect(animateItems ? 1 : 0.6)
                            .opacity(animateItems ? 1 : 0)
                            .padding(.top, 10)
                        
                        // Header
                        VStack(spacing: 8) {
                            Text("Great Job!")
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Text("You've safely completed your trip.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .scaleEffect(animateItems ? 1 : 0.8)
                        .opacity(animateItems ? 1 : 0)
                        
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
                                        Text(String(format: "%.1f km", distance))
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
                        .background(AppColor.surface)
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
                        .background(AppColor.surface)
                        .cornerRadius(24)
                        .shadow(color: Color.black.opacity(0.04), radius: 10, y: 5)
                        .offset(y: animateItems ? 0 : 50)
                        .opacity(animateItems ? 1 : 0)
                        .padding(.bottom, 30)
                    }
                    .padding(.horizontal, 24)
                }
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

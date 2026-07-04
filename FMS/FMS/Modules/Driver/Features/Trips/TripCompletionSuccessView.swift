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
                for _ in 0..<50 {
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
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            ConfettiEmitterView()
            
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
                    
                    // Route Map Card
                    VStack(alignment: .leading, spacing: 12) {
                        ZStack(alignment: .bottomLeading) {
                            Map(initialPosition: .region(MKCoordinateRegion(
                                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                            ))) {
                                Annotation("Trip Route", coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)) {
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 12, height: 12)
                                }
                            }
                            .frame(height: 160)
                            .cornerRadius(18)
                            .disabled(true)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Route Optimized")
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
                    
                    // Button
                    Button(action: onDismiss) {
                        HStack {
                            Text("Return to Map")
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
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0).delay(0.1)) {
                animateItems = true
            }
        }
    }
}

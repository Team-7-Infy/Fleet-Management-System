import SwiftUI
import MapKit

struct ActiveTrackingView: View {
    @EnvironmentObject var locationService: LocationManager
    
    @State private var showingEndTripSheet = false
    @State private var slideProgress: CGFloat = 0.0
    
    // THE FIX: State to delay the map rendering
    @State private var isMapReady: Bool = false
    
    // Simulated live data
    let destination = "Central Warehouse, Block B"
    let eta = "14:30 PM"
    let distanceRemaining = "24.5 km"
    
    var body: some View {
        ZStack(alignment: .bottom) {
            
            // 1. LAZY LOADED MAP
            if isMapReady {
                Map(coordinateRegion: $locationService.region, showsUserLocation: true)
                    .ignoresSafeArea(edges: .top)
                    .transition(.opacity) // Fades in smoothly
            } else {
                // Lightweight placeholder while the tab animates
                ZStack {
                    Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading Telemetry...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // 2. Floating Top Bar
            VStack {
                HStack {
                    VStack(alignment: .leading) {
                        Text("ACTIVE TRIP")
                            .font(.caption)
                            .fontWeight(.black)
                            .foregroundColor(.blue)
                        Text("Awaiting Trip...")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    Spacer()
                    
                    // Quick SOS Floating Button
                    Button(action: {}) {
                        Image(systemName: "light.beacon.max.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Circle().fill(Color.red).shadow(radius: 5))
                    }
                }
                .padding()
                .background(.regularMaterial)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                .padding(.horizontal)
                .padding(.top, 10)
                
                Spacer()
            }
            
            // 3. Telemetry Bottom Sheet (Only shows when map is ready)
            if isMapReady {
                VStack(spacing: 20) {
                    Capsule()
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 40, height: 5)
                        .padding(.top, 10)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Navigating to")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(destination)
                                .font(.title3)
                                .fontWeight(.bold)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    HStack(spacing: 15) {
                        TelemetryWidget(title: "ETA", value: eta, icon: "clock.fill", color: .blue)
                        TelemetryWidget(title: "Remaining", value: distanceRemaining, icon: "location.fill", color: .green)
                    }
                    .padding(.horizontal)
                    
                    SlideToComplete(progress: $slideProgress, onComplete: {
                        showingEndTripSheet = true
                    })
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                .background(.ultraThinMaterial)
                .cornerRadius(30, corners: [.topLeft, .topRight])
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: -5)
                .transition(.move(edge: .bottom)) // Slides up gracefully
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingEndTripSheet) {
            EndTripView()
        }
        .onAppear {
            locationService.requestPermission()
            
            // THE FIX: Wait exactly 0.3 seconds for the tab animation to finish, THEN load the heavy map
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeIn(duration: 0.4)) {
                    isMapReady = true
                }
            }
        }
    }
}

// ... (Keep your existing TelemetryWidget and SlideToComplete components at the bottom)
// MARK: - Custom UI Components

struct TelemetryWidget: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .minimumScaleFactor(0.8) // Shrinks if text is too long
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(UIColor.systemBackground).opacity(0.8))
        .cornerRadius(16)
    }
}

struct SlideToComplete: View {
    @Binding var progress: CGFloat
    var onComplete: () -> Void
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Track
            RoundedRectangle(cornerRadius: 30)
                .fill(Color.black)
                .frame(height: 60)
            
            Text("SLIDE TO END TRIP")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.white.opacity(0.6))
                .frame(maxWidth: .infinity)
            
            // Slider Thumb
            HStack {
                Spacer().frame(width: progress * (UIScreen.main.bounds.width - 110))
                
                Image(systemName: "chevron.right.2")
                    .font(.title3)
                    .foregroundColor(.black)
                    .frame(width: 60, height: 60)
                    .background(Color.white)
                    .clipShape(Circle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let maxSlide: CGFloat = UIScreen.main.bounds.width - 110
                                if value.translation.width > 0 && value.translation.width <= maxSlide {
                                    progress = value.translation.width / maxSlide
                                }
                            }
                            .onEnded { value in
                                if progress > 0.85 {
                                    progress = 1.0
                                    onComplete()
                                } else {
                                    withAnimation(.spring()) {
                                        progress = 0.0
                                    }
                                }
                            }
                    )
            }
        }
    }
}

// MARK: - Specific Corner Radius Helper

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

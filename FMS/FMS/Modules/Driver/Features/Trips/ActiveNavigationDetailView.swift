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
    
    @Published var distanceCovered: String = "120 km"
    @Published var distanceRemaining: String = "45 km"
    @Published var eta: String = "14:30 PM"
    
    let tripId: String
    let services: AppServices
    private var cancellables = Set<AnyCancellable>()
    
    init(tripId: String, services: AppServices, start: CLLocationCoordinate2D, end: CLLocationCoordinate2D, destinationName: String) {
        self.tripId = tripId
        self.services = services
        self.startCoordinate = start
        self.endCoordinate = end
        self.destinationName = destinationName
        calculateRoute()
        
        Task { @MainActor in
            await fetchWaypoints()
        }
    }
    
    func fetchWaypoints() async {
        guard let tripUUID = UUID(uuidString: tripId) else { return }
        do {
            let waypoints = try await services.tripService.fetchRouteWaypoints(tripId: tripUUID)
            if !waypoints.isEmpty, let last = waypoints.last {
                endCoordinate = CLLocationCoordinate2D(latitude: last.latitude, longitude: last.longitude)
                destinationName = "Waypoint \(last.sequenceOrder)"
                calculateRoute()
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
    @State private var showingCompletionForm = false
    
    // General SOS alerts
    @State private var showingSOSAlert = false
    
    // Track last location used for route calculation (throttling MKDirections)
    @State private var lastCalculatedLocation: CLLocation? = nil
    
    // Trip transit and pause controls
    @State private var isTripStopped = false
    @State private var showingFuelSheet = false
    
    // Dispatch Chat States
    @State private var showingChatView = false
    
    // Sliding bottom sheet state variables
    @State private var sheetOffset: CGFloat = 0.0
    @State private var lastOffset: CGFloat = 0.0
    
    var collapsedOffset: CGFloat {
        330.0
    }
    
    private var assignedVehicle: String {
        vehicles.first(where: { $0.id == trip.vehicleId })?.licencePlate ?? ""
    }
    
    init(services: AppServices, user: User, driver: Driver?, trip: Trip, vehicles: [Vehicle], onBack: @escaping () -> Void) {
        self.services = services
        self.user = user
        self.driver = driver
        self.trip = trip
        self.vehicles = vehicles
        self.onBack = onBack
        
        let start = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let end = CLLocationCoordinate2D(latitude: 37.7869, longitude: -122.4074)
        
        _viewModel = StateObject(wrappedValue: LiveNavigationViewModel(
            tripId: trip.id.uuidString,
            services: services,
            start: start,
            end: end,
            destinationName: trip.endLocation
        ))
    }
    
    var startCoordinate: CLLocationCoordinate2D {
        locationService.location?.coordinate ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    }
    
    func focusOnDriverAndRoute() {
        let center = locationService.location?.coordinate ?? viewModel.startCoordinate
        let region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: 600,
            longitudinalMeters: 600
        )
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            cameraPosition = .region(region)
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            
            // 1. Live iOS 17+ Map View
            Map(position: $cameraPosition) {
                UserAnnotation()
                
                Marker(viewModel.destinationName, systemImage: "flag.checkered.circle.fill", coordinate: viewModel.endCoordinate)
                    .tint(.green)
                
                if !viewModel.routeCoordinates.isEmpty {
                    MapPolyline(coordinates: viewModel.routeCoordinates)
                        .stroke(Color.blue, lineWidth: 6)
                }
            }
            .ignoresSafeArea()
            
            // 2. Floating Actions Overlay at the Top
            VStack {
                ZStack {
                    // Centered Destination info label
                    HStack {
                        Spacer()
                        HStack {
                            Image(systemName: "flag.checkered.circle.fill")
                                .foregroundColor(.green)
                            Text(trip.endLocation)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.08), radius: 4)
                        Spacer()
                    }
                    
                    // Left Exit Button
                    HStack {
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
                        .accessibilityLabel("Exit Navigation")
                        Spacer()
                    }
                    
                    // Right Chat Button
                    HStack {
                        Spacer()
                        Button(action: {
                            HapticManager.shared.triggerImpact(style: .medium)
                            showingChatView = true
                        }) {
                            Image(systemName: "message.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.blue)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(Color(UIColor.systemBackground)))
                                .shadow(color: .black.opacity(0.1), radius: 4)
                        }
                        .accessibilityLabel("Dispatch Chat")
                    }
                }
                .padding()
                Spacer()
            }
            
            
            // 3.5 Floating "SHOW TELEMETRY" button when panel is collapsed
            VStack {
                Spacer()
                if sheetOffset > collapsedOffset - 50 {
                    Button(action: {
                        HapticManager.shared.triggerImpact(style: .medium)
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            sheetOffset = 0
                            lastOffset = 0
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.up")
                                .fontWeight(.black)
                            Text("SHOW TELEMETRY")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .tracking(1.5)
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .environment(\.colorScheme, .light)
                                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if value.translation.height < 0 {
                                    sheetOffset = collapsedOffset + value.translation.height
                                }
                            }
                            .onEnded { value in
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                    if sheetOffset < collapsedOffset - 50 {
                                        sheetOffset = 0
                                    } else {
                                        sheetOffset = collapsedOffset
                                    }
                                    lastOffset = sheetOffset
                                }
                            }
                    )
                }
            }
            
            // 4. Structured Driver Journey Dashboard Panel
            VStack(spacing: 20) {
                // Drag Handle Indicator
                Capsule()
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 36, height: 5)
                    .padding(.top, 10)
                
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isTripStopped ? "TRIP STOPPED / PAUSED" : "ACTIVE DISPATCH TELEMETRY")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(isTripStopped ? .red : .blue)
                        Text(trip.id.uuidString)
                            .font(.title2)
                            .fontWeight(.black)
                            .foregroundColor(.primary)
                    }
                    Spacer()
                    
                    // Simple live tracking beacon
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isTripStopped ? Color.red : Color.green)
                            .frame(width: 8, height: 8)
                        Text(isTripStopped ? "STOPPED" : "EN ROUTE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(isTripStopped ? .red : .green)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(isTripStopped ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                    .clipShape(Capsule())
                }
                .padding(.horizontal)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        sheetOffset = (sheetOffset == 0) ? collapsedOffset : 0
                        lastOffset = sheetOffset
                    }
                }
                
                VStack(spacing: 20) {
                    // Navigation HUD (Driver Guidance Mode)
                    HStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("ETA")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            Text(viewModel.eta)
                                .font(.title3)
                                .fontWeight(.black)
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .center, spacing: 6) {
                            Text("REMAINING")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            Text(viewModel.distanceRemaining)
                                .font(.title3)
                                .fontWeight(.black)
                                .foregroundColor(.green)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 6) {
                            Text("SPEED")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            Text(isTripStopped ? "0 km/h" : "65 km/h")
                                .font(.title3)
                                .fontWeight(.black)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider().padding(.horizontal)
                    
                    // Core action buttons: Fuel and SOS
                    HStack(spacing: 12) {
                        Button(action: {
                            HapticManager.shared.triggerImpact(style: .medium)
                            showingFuelSheet = true
                        }) {
                            HStack {
                                Image(systemName: "fuelpump.fill")
                                Text("Add Fuel")
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue)
                            .cornerRadius(14)
                            .shadow(color: Color.blue.opacity(0.2), radius: 5)
                        }
                        
                        Button(action: {
                            HapticManager.shared.triggerNotification(type: .error)
                            showingSOSAlert = true
                        }) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text("Emergency SOS")
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.red)
                            .cornerRadius(14)
                            .shadow(color: Color.red.opacity(0.2), radius: 5)
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider().padding(.horizontal)
                    
                    if !isTripStopped {
                        // Running Actions
                        HStack(spacing: 12) {
                            Button(action: {
                                HapticManager.shared.triggerImpact(style: .medium)
                                withAnimation(.spring()) {
                                    isTripStopped = true
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "pause.fill")
                                    Text("STOP TRIP")
                                        .fontWeight(.black)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.orange)
                                .cornerRadius(16)
                                .shadow(color: Color.orange.opacity(0.3), radius: 6)
                            }
                            
                            Button(action: {
                                HapticManager.shared.triggerImpact(style: .medium)
                                showingCompletionForm = true
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.seal.fill")
                                    Text("COMPLETE TRIP")
                                        .fontWeight(.black)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    LinearGradient(
                                        colors: [Color(red: 0.15, green: 0.75, blue: 0.35), Color(red: 0.05, green: 0.55, blue: 0.25)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(16)
                                .shadow(color: Color.green.opacity(0.3), radius: 6)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 38)
                        
                    } else {
                        // Stopped Actions (Shows Resume button)
                        VStack(spacing: 14) {
                            Button(action: {
                                HapticManager.shared.triggerImpact(style: .medium)
                                withAnimation(.spring()) {
                                    isTripStopped = false
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "play.fill")
                                    Text("RESUME TRIP")
                                        .fontWeight(.black)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.blue)
                                .cornerRadius(16)
                                .shadow(color: Color.blue.opacity(0.3), radius: 6)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 38)
                    }
                }
                .opacity(Double(1.0 - (sheetOffset / collapsedOffset)))
                .frame(height: sheetOffset == collapsedOffset ? 0 : nil)
                .clipped()
            }
            .background(
                RoundedRectangle(cornerRadius: 30)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .light)
                    .shadow(color: Color.black.opacity(0.12), radius: 20, x: 0, y: -5)
            )
            .offset(y: sheetOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let newOffset = lastOffset + value.translation.height
                        if newOffset >= -20 && newOffset <= collapsedOffset {
                            sheetOffset = newOffset
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            if sheetOffset > collapsedOffset / 3 {
                                sheetOffset = collapsedOffset
                            } else {
                                sheetOffset = 0
                            }
                            lastOffset = sheetOffset
                        }
                    }
            )
            .ignoresSafeArea(edges: .bottom)
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingFuelSheet) {
            FuelRequestView(assignedVehicle: assignedVehicle)
                .environmentObject(localStore)
        }
        .sheet(isPresented: $showingCompletionForm) {
            TripCompletionFormView(
                activeTripId: trip.id.uuidString,
                trip: trip,
                onComplete: { finalOdometer, finalFuelLevel, needsMaintenance, driverNote in
                    Task {
                        var updatedTrip = trip
                        updatedTrip.finalOdometer = Double(finalOdometer)
                        updatedTrip.finalFuelLevel = Double(finalFuelLevel.trimmingCharacters(in: CharacterSet(charactersIn: "%"))) ?? 75.0
                        updatedTrip.status = .completed
                        updatedTrip.endTime = Date()
                        updatedTrip.driverNote = driverNote
                        try? await services.tripService.updateTrip(updatedTrip)
                    }
                    onBack()
                }
            )
            .environmentObject(localStore)
        }
        .alert(isPresented: $showingSOSAlert) {
            Alert(
                title: Text("EMERGENCY SOS"),
                message: Text("Triggering SOS will instantly broadcast your live coordinates and alert fleet dispatch."),
                primaryButton: .destructive(Text("CONFIRM EMERGENCY SOS")) {
                    print("Emergency SOS Triggered!")
                    Task {
                        try? await services.tripService.updateTripStatus(
                            id: trip.id,
                            status: .rejected,
                            rejectionReason: "SOS Emergency: Automatically cancelled via emergency SOS alert during active navigation."
                        )
                    }
                    onBack()
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
                Task {
                    try? await services.tripService.updateTripStatus(
                        id: trip.id,
                        status: .rejected,
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
        .sheet(isPresented: $showingChatView) {
            FleetManagerChatView()
        }
        .onAppear {
            locationService.requestPermission()
            locationService.startTracking()
            
            let userLocation = startCoordinate
            viewModel.startCoordinate = userLocation
            viewModel.endCoordinate = CLLocationCoordinate2D(latitude: userLocation.latitude + 0.012, longitude: userLocation.longitude + 0.012)
            viewModel.calculateRoute()
        }
        .onReceive(locationService.$location) { newLocation in
            guard let newLocation = newLocation else { return }
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                cameraPosition = .userLocation(followsHeading: true, fallback: .automatic)
            }
            
            let isInitialUpdate = (viewModel.startCoordinate.latitude == 37.7749 && viewModel.startCoordinate.longitude == -122.4194)
            
            if isInitialUpdate {
                viewModel.startCoordinate = newLocation.coordinate
                viewModel.endCoordinate = CLLocationCoordinate2D(
                    latitude: newLocation.coordinate.latitude + 0.012,
                    longitude: newLocation.coordinate.longitude + 0.012
                )
                viewModel.calculateRoute()
                lastCalculatedLocation = newLocation
            } else if let lastLoc = lastCalculatedLocation {
                if newLocation.distance(from: lastLoc) > 200 {
                    viewModel.startCoordinate = newLocation.coordinate
                    viewModel.calculateRoute()
                    lastCalculatedLocation = newLocation
                }
            } else {
                lastCalculatedLocation = newLocation
            }
        }
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
        }
    }
}

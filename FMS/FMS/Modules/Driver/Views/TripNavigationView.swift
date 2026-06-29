import SwiftUI
import MapKit

struct TripNavigationView: View {
    @StateObject private var viewModel: TripNavigationViewModel
    @Environment(\.dismiss) private var dismiss

    let onEndTrip: () -> Void

    init(
        trip: Trip,
        tripService: TripServiceProtocol,
        locationManager: DriverLocationManager,
        onEndTrip: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: TripNavigationViewModel(
            trip: trip,
            tripService: tripService,
            locationManager: locationManager
        ))
        self.onEndTrip = onEndTrip
    }

    var body: some View {
        ZStack(alignment: .top) {
            mapView

            VStack {
                if viewModel.isOffRoute {
                    deviationBanner
                }
                Spacer()
                bottomSheet
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationTitle("Trip Navigation")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadWaypoints()
        }
        .onDisappear {
            viewModel.stopPolling()
        }
        .alert("Deviation Alert", isPresented: .init(
            get: { viewModel.deviationAlertMessage != nil },
            set: { if !$0 { viewModel.deviationAlertMessage = nil } }
        )) {
            Button("OK") { viewModel.deviationAlertMessage = nil }
        } message: {
            Text(viewModel.deviationAlertMessage ?? "")
        }
    }

    private var mapView: some View {
        Map(
            coordinateRegion: .constant(viewModel.region),
            showsUserLocation: true,
            userTrackingMode: .constant(.follow),
            annotationItems: viewModel.waypoints
        ) { waypoint in
            MapAnnotation(
                coordinate: CLLocationCoordinate2D(
                    latitude: waypoint.latitude,
                    longitude: waypoint.longitude
                )
            ) {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: CGFloat(waypoint.bufferRadius / 4), height: CGFloat(waypoint.bufferRadius / 4))
                    .overlay(
                        Circle()
                            .stroke(Color.blue, lineWidth: 1)
                    )
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
    }

    private var deviationBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)
            Text("Off Route — \(Int(viewModel.offRouteDistance))m from planned path")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            Spacer()
        }
        .padding()
        .background(Color.red.opacity(0.9))
        .cornerRadius(8)
        .padding(.horizontal)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut, value: viewModel.isOffRoute)
    }

    private var bottomSheet: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.trip.startLocation)
                        .font(.headline)
                    Text("→")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(viewModel.trip.endLocation)
                        .font(.headline)
                }

                Spacer()

                if let distance = viewModel.route?.distance {
                    VStack(alignment: .trailing) {
                        Text(String(format: "%.1f km", distance / 1000))
                            .font(.title2.weight(.bold))
                        Text("total")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()

            Button {
                onEndTrip()
                dismiss()
            } label: {
                Label("End Trip", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .padding(.horizontal)
        }
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .cornerRadius(16, corners: [.topLeft, .topRight])
    }
}



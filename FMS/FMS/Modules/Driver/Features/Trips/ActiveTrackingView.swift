import SwiftUI

struct ActiveTrackingView: View {
    @Binding var showingProfile: Bool
    let trips: [Trip]
    var services: AppServices? = nil
    var user: User? = nil
    var driver: Driver? = nil
    var vehicles: [Vehicle] = []

    @EnvironmentObject var localStore: LocalDataStore
    @EnvironmentObject var locationService: LocationManager

    @State private var selectedTrip: Trip? = nil
    @State private var showingActiveNavigation = false
    @State private var showingSOSAlert = false
    @State private var showingFuelSheet = false
    @State private var showingTripDetailsSheet = false
    @State private var isPastTripsExpanded = false

    private var activeTripId: String? {
        trips.first(where: { $0.status == .inProgress })?.id.uuidString
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        HStack(alignment: .center) {
                            Text("Trips")
                                .font(.system(size: 34, weight: .heavy, design: .default))
                                .foregroundColor(.primary)
                                .accessibilityAddTraits(.isHeader)

                            Spacer()

                            Button(action: {
                                HapticManager.shared.triggerImpact(style: .medium)
                                showingProfile = true
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.blue, Color(red: 0.1, green: 0.3, blue: 0.9)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 36, height: 36)
                                        .shadow(color: Color.blue.opacity(0.2), radius: 4, x: 0, y: 2)

                                    Text("AJ")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .padding(.top, 10)


                        // Upcoming Trips Section (Scheduled or Accepted) - max 3 cards
                        let upcomingTrips = trips.filter {
                            ($0.status == .pending || $0.status == .accepted) && abs($0.startTime.timeIntervalSinceNow) >= 3600
                        }
                        let displayedUpcomingTrips = Array(upcomingTrips.prefix(3))

                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Upcoming Trips")

                            if displayedUpcomingTrips.isEmpty {
                                Text("No upcoming trips scheduled")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 8)
                            } else {
                                VStack(spacing: 16) {
                                    ForEach(displayedUpcomingTrips) { trip in
                                        UpcomingTripCard(trip: trip)
                                            .onTapGesture {
                                                selectedTrip = trip
                                            }
                                    }
                                }
                            }
                        }

                        // Past Trips Section (Completed, Delivered, or Cancelled) - max 3 by default, expandable via chevron
                        let pastTrips = trips.filter { $0.status == .completed || $0.status == .rejected }
                        let displayedPastTrips = isPastTripsExpanded ? pastTrips : Array(pastTrips.prefix(3))

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                SectionHeader(title: "Past Trips")
                                Spacer()
                                if pastTrips.count > 3 {
                                    Button(action: {
                                        withAnimation {
                                            isPastTripsExpanded.toggle()
                                        }
                                    }) {
                                        HStack(spacing: 4) {
                                            Text(isPastTripsExpanded ? "Show Less" : "See All")
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.blue)
                                            Image(systemName: isPastTripsExpanded ? "chevron.up" : "chevron.down")
                                                .font(.subheadline)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }

                            if displayedPastTrips.isEmpty {
                                Text("No past trips recorded")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 8)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(Array(displayedPastTrips.enumerated()), id: \.element.id) { index, trip in
                                        Button(action: { selectedTrip = trip }) {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(trip.endLocation)
                                                        .font(.subheadline)
                                                        .fontWeight(.bold)
                                                        .foregroundColor(.secondary)
                                                    Text("Trip: \(trip.id.uuidString.prefix(8).uppercased())")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary.opacity(0.7))
                                                }
                                                Spacer()
                                                Text(trip.status.rawValue.capitalized)
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundColor(trip.status == .rejected ? .red : .secondary.opacity(0.6))
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 6)
                                                    .background(trip.status == .rejected ? Color.red.opacity(0.1) : Color(UIColor.systemGroupedBackground))
                                                    .clipShape(Capsule())
                                            }
                                            .padding(20)
                                        }
                                        .buttonStyle(PlainButtonStyle())

                                        if index < displayedPastTrips.count - 1 {
                                            Divider().padding(.leading, 20)
                                        }
                                    }
                                }
                                .background(Color(UIColor.systemBackground).opacity(0.75))
                                .cornerRadius(20)
                                .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 4)
                            }
                        }

                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 40)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $selectedTrip) { trip in
                NavigationStack {
                    TripDetailView(trip: trip)
                        .environmentObject(localStore)
                }
            }
            .fullScreenCover(isPresented: $showingActiveNavigation) {
                if let activeTrip = trips.first(where: { $0.status == .inProgress }),
                   let services, let user {
                    ActiveNavigationDetailView(
                        services: services,
                        user: user,
                        driver: driver,
                        trip: activeTrip,
                        vehicles: vehicles,
                        onBack: { showingActiveNavigation = false }
                    )
                    .environmentObject(localStore)
                    .environmentObject(locationService)
                }
            }
            .alert(isPresented: $showingSOSAlert) {
                Alert(
                    title: Text("EMERGENCY SOS"),
                    message: Text("Are you sure you want to trigger an SOS? This will instantly alert dispatch and share your live location."),
                    primaryButton: .destructive(Text("Trigger SOS")) {
                        print("SOS Triggered!")
                    },
                    secondaryButton: .cancel()
                )
            }
            .sheet(isPresented: $showingFuelSheet) {
                TripFuelHistoryView()
            }
            .sheet(isPresented: $showingTripDetailsSheet) {
                ActiveTripDetailView(
                    tripId: activeTripId ?? "TRP-8472",
                    startLocation: "Bengaluru Yard",
                    endLocation: "Pune Distribution Hub",
                    distanceCovered: "120 km",
                    distanceRemaining: "45 km",
                    startTime: "08:32 AM",
                    endTime: "14:30 PM",
                    remainingTime: "2h 15m",
                    progress: 0.65
                )
                .environmentObject(localStore)
            }
        }
    }
}

// MARK: - Upcoming Trip Card (Inline replacement for PendingRequestCard)
private struct UpcomingTripCard: View {
    let trip: Trip

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(trip.id.uuidString.prefix(8).uppercased())
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.blue)
                Spacer()
                Text(trip.status.rawValue.capitalized)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.08))
                    .clipShape(Capsule())
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2, height: 40)
                    Image(systemName: "flag.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 8))
                }
                .padding(.top, 4)

                VStack(alignment: .leading, spacing: 8) {
                    Text(trip.startLocation)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 4) {
                        Image(systemName: "road.lanes")
                            .font(.system(size: 9))
                            .foregroundColor(.purple)
                        Text("-- km")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text(trip.endLocation)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                }
            }
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 4)
    }
}

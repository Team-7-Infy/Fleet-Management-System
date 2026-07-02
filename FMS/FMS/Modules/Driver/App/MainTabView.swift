import SwiftUI

struct MainTabView: View {
    @StateObject private var locationService = LocationManager()
    @StateObject private var networkMonitor = NetworkMonitor()

    var body: some View {
        ZStack(alignment: .top) {
            TabView {
                DashboardPlaceholder()
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }

                ActiveTrackingView(showingProfile: .constant(false), trips: [])
                    .tabItem {
                        Label("Trip", systemImage: "location.north.line.fill")
                    }

                VehicleHubView()
                    .tabItem {
                        Label("Vehicle", systemImage: "car.fill")
                    }

                ProfileTabView()
                    .tabItem {
                        Label("Profile", systemImage: "person.crop.circle.fill")
                    }
            }
            .accentColor(.blue)

            if !networkMonitor.isConnected {
                OfflineBanner()
                    .transition(.move(edge: .top))
                    .animation(.easeInOut, value: networkMonitor.isConnected)
            }
        }
        .environmentObject(locationService)
        .environmentObject(networkMonitor)
        .environmentObject(LocalDataStore.shared)
    }
}

private struct DashboardPlaceholder: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "car.fill").font(.system(size: 48)).foregroundColor(.blue)
            Text("Driver Dashboard").font(.title2).fontWeight(.bold)
            Text("Use DriverDashboardView as entry point").foregroundColor(.secondary)
        }
    }
}

struct VehicleHubView: View {
    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: InspectionTripPlaceholder()) {
                    Label("Pre-Trip Inspection", systemImage: "checklist")
                }
                NavigationLink(destination: FuelManagementPlaceholder()) {
                    Label("Fuel Management", systemImage: "fuelpump.fill")
                }
                NavigationLink(destination: IncidentReportPlaceholder()) {
                    Label("Report Incident", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("Vehicle Hub")
        }
    }
}

private struct InspectionTripPlaceholder: View {
    var body: some View {
        Text("Inspection view requires trip context")
            .padding()
    }
}

struct ProfileTabView: View {
    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: PerformanceView()) {
                    Label("My Performance", systemImage: "chart.bar.fill")
                }
                NavigationLink(destination: ProfilePlaceholder()) {
                    Label("Account", systemImage: "person.crop.circle.fill")
                }
            }
            .navigationTitle("My Profile")
        }
    }
}

private struct ProfilePlaceholder: View {
    var body: some View {
        Text("Profile requires services context")
            .padding()
    }
}

private struct FuelManagementPlaceholder: View {
    var body: some View {
        Text("Fuel management requires trip context").padding()
    }
}

private struct IncidentReportPlaceholder: View {
    var body: some View {
        Text("Incident report requires trip context").padding()
    }
}

struct OfflineBanner: View {
    var body: some View {
        HStack {
            Image(systemName: "wifi.slash")
            Text("Offline Mode. Data is saving locally.")
                .font(.footnote)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.red)
        .foregroundColor(.white)
        .ignoresSafeArea(.all, edges: .top)
    }
}

import SwiftUI

struct MainTabView: View {
    @StateObject private var locationService = LocationManager()
    @StateObject private var networkMonitor = NetworkMonitor()

    var body: some View {
        ZStack(alignment: .top) {
            TabView {
                DashboardView()
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }

                ActiveTrackingView()
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
            .accentColor(FleetPalette.accent)

            if !networkMonitor.isConnected {
                OfflineBanner()
                    .transition(.move(edge: .top))
                    .animation(.easeInOut, value: networkMonitor.isConnected)
            }
        }
        .environmentObject(locationService)
        .environmentObject(networkMonitor)
    }
}

struct VehicleHubView: View {
    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: InspectionView()) {
                    Label("Pre-Trip Inspection", systemImage: "checklist")
                }
                NavigationLink(destination: FuelHistoryView()) {
                    Label("Fuel Management", systemImage: "fuelpump.fill")
                }
                NavigationLink(destination: IncidentReportView()) {
                    Label("Report Incident", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(FleetPalette.danger)
                }
            }
            .navigationTitle("Vehicle Hub")
        }
    }
}

struct ProfileTabView: View {
    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: PerformanceView()) {
                    Label("My Performance", systemImage: "chart.bar.fill")
                }
                NavigationLink(destination: DocumentCenterView()) {
                    Label("Document Center", systemImage: "doc.text.fill")
                }
                NavigationLink(destination: ProfileHubView()) {
                    Label("Account", systemImage: "person.crop.circle.fill")
                }
            }
            .navigationTitle("My Profile")
        }
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
        .background(FleetPalette.danger)
        .foregroundColor(.white)
        .ignoresSafeArea(.all, edges: .top)
    }
}

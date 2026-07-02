
import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    
    // MARK: - Navigation States for Quick Actions
    @State private var showingSOSAlert = false
    @State private var showingFuelSheet = false
    @State private var showingLogbookSheet = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        HomeHeaderView()
                        
                        if viewModel.activeTripId != nil {
                            ActiveRouteCard(
                                nextStop: "Pune Distribution Hub",
                                address: "Gate 4, Sector 7",
                                eta: "14:30 PM",
                                progress: 0.65
                            )
                        }
                        
                        if viewModel.pendingTasks > 0 {
                            UrgentTaskCard(title: "Pre-Trip Inspection Required", type: "SAFETY BLOCK")
                        }
                        
                        HStack(spacing: 16) {
                            ComplianceWidget(title: "Drive Time", value: "4h 12m", subtitle: "until required break", progress: 0.7, color: FleetPalette.inProgress)
                            ComplianceWidget(title: "Fuel Level", value: "65%", subtitle: "Est. 240 km left", progress: 0.65, color: FleetPalette.warning)
                        }
                        
                        // QUICK ACTIONS - Now wired to our state variables
                        SectionHeader(title: "Quick Actions")
                        QuickActionRow(
                            onLogbookTap: { showingLogbookSheet = true },
                            onFuelTap: { showingFuelSheet = true },
                            onSOSTap: { showingSOSAlert = true }
                        )
                        
                        SectionHeader(title: "Today's Manifest")
                        ManifestList()
                        
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                viewModel.fetchDashboardData()
            }
            // MARK: - Action Triggers
            .alert(isPresented: $showingSOSAlert) {
                Alert(
                    title: Text("EMERGENCY SOS"),
                    message: Text("Are you sure you want to trigger an SOS? This will instantly alert dispatch and share your live location."),
                    primaryButton: .destructive(Text("Trigger SOS")) {
                        // Add real SOS network call here later
                        print("SOS Triggered!")
                    },
                    secondaryButton: .cancel()
                )
            }
            .sheet(isPresented: $showingFuelSheet) {
                FuelLogView()
            }
            .sheet(isPresented: $showingLogbookSheet) {
                LogbookView()
            }
        }
    }
}

// MARK: - 1. Header
struct HomeHeaderView: View {
    var body: some View {
        HStack(alignment: .center) {
            Text("Home")
                .font(.system(size: 34, weight: .heavy, design: .default))
                .foregroundColor(.primary)
            Spacer()
            Button(action: {}) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(Circle())
                    Circle()
                        .fill(FleetPalette.danger)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color(UIColor.systemGroupedBackground), lineWidth: 2))
                        .offset(x: -2, y: 2)
                }
            }
        }
    }
}

// MARK: - 2. Active Route Card
struct ActiveRouteCard: View {
    let nextStop: String
    let address: String
    let eta: String
    let progress: Double
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(FleetPalette.success).frame(width: 8, height: 8).shadow(color: FleetPalette.success, radius: 4)
                    Text("ON ROUTE")
                        .font(.caption).fontWeight(.heavy).foregroundColor(.white)
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.ultraThinMaterial).environment(\.colorScheme, .dark).clipShape(Capsule())
                Spacer()
                Text(eta).font(.system(size: 24, weight: .heavy, design: .rounded)).foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Next Stop").font(.subheadline).fontWeight(.medium).foregroundColor(.white.opacity(0.8))
                Text(nextStop).font(.system(size: 26, weight: .heavy, design: .default)).foregroundColor(.white)
                Text(address).font(.subheadline).foregroundColor(.white.opacity(0.8))
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.2)).frame(height: 8)
                    Capsule().fill(Color.white).frame(width: geometry.size.width * progress, height: 8).shadow(color: .white.opacity(0.5), radius: 5, x: 0, y: 0)
                }
            }
            .frame(height: 8).padding(.top, 4)
            Button(action: {}) {
                HStack {
                    Image(systemName: "location.north.line.fill")
                    Text("Open Navigation")
                }
                .font(.headline).fontWeight(.bold).frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(.ultraThinMaterial).environment(\.colorScheme, .dark).foregroundColor(.white).cornerRadius(16)
            }
        }
        .padding(24)
        .background(LinearGradient(colors: [FleetPalette.inProgress, FleetPalette.secondary], startPoint: .topLeading, endPoint: .bottomTrailing))
        .cornerRadius(24).shadow(color: FleetPalette.inProgress.opacity(0.25), radius: 20, x: 0, y: 12)
    }
}

// MARK: - 3. Urgent Task Card
struct UrgentTaskCard: View {
    let title: String
    let type: String
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(FleetPalette.danger.opacity(0.15)).frame(width: 50, height: 50)
                Image(systemName: "exclamationmark.shield.fill").foregroundColor(FleetPalette.danger).font(.title2)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(type).font(.system(size: 11, weight: .black)).foregroundColor(FleetPalette.danger)
                Text(title).font(.headline).fontWeight(.bold).foregroundColor(.primary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.gray.opacity(0.5))
        }
        .padding(20).background(Color(UIColor.systemBackground)).cornerRadius(20).shadow(color: FleetPalette.danger.opacity(0.1), radius: 15, x: 0, y: 5)
    }
}

// MARK: - 4. Compliance & Vitals Widget
struct ComplianceWidget: View {
    let title: String
    let value: String
    let subtitle: String
    let progress: Double
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.subheadline).fontWeight(.bold).foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.system(size: 24, weight: .heavy, design: .rounded)).foregroundColor(.primary)
                Text(subtitle).font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(UIColor.systemGroupedBackground)).frame(height: 6)
                    Capsule().fill(color).frame(width: geometry.size.width * progress, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Color(UIColor.systemBackground))
        .cornerRadius(20).shadow(color: Color.black.opacity(0.03), radius: 15, x: 0, y: 5)
    }
}

// MARK: - 5. Quick Action Row (UPDATED FOR INTERACTIVITY)
struct QuickActionRow: View {
    let onLogbookTap: () -> Void
    let onFuelTap: () -> Void
    let onSOSTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            ActionTile(icon: "book.pages.fill", title: "Logbook", color: .purple, action: onLogbookTap)
            ActionTile(icon: "fuelpump.fill", title: "Fuel", color: FleetPalette.warning, action: onFuelTap)
            ActionTile(icon: "light.beacon.max.fill", title: "SOS", color: FleetPalette.danger, action: onSOSTap)
        }
    }
}

struct ActionTile: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle()) // Keeps the custom colors intact on press
    }
}

// MARK: - 6. Manifest List
struct ManifestList: View {
    var body: some View {
        VStack(spacing: 0) {
            ManifestRow(id: "TRP-083", destination: "Nashik Distribution Hub", status: "Pending")
            Divider().padding(.leading, 20)
            ManifestRow(id: "TRP-084", destination: "Surat Port Authority", status: "Scheduled")
        }
        .background(Color(UIColor.systemBackground)).cornerRadius(20).shadow(color: Color.black.opacity(0.03), radius: 15, x: 0, y: 5)
    }
}

struct ManifestRow: View {
    let id: String
    let destination: String
    let status: String
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(destination).font(.subheadline).fontWeight(.bold)
                Text("Trip: \(id)").font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Text(status).font(.system(size: 11, weight: .bold)).foregroundColor(.secondary).padding(.horizontal, 10).padding(.vertical, 6).background(Color(UIColor.systemGroupedBackground)).clipShape(Capsule())
        }
        .padding(20)
    }
}

struct SectionHeader: View {
    let title: String
    var body: some View {
        HStack { Text(title).font(.title3).fontWeight(.bold).foregroundColor(.primary); Spacer() }
    }
}


// MARK: - STUBS FOR SHEETS (Add these so the project compiles)

struct FuelLogView: View {
    @Environment(\.presentationMode) var presentationMode
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "fuelpump.fill").font(.system(size: 60)).foregroundColor(FleetPalette.warning)
                Text("Log Fuel Stop").font(.title2).fontWeight(.bold)
                Text("Fuel submission form will go here.").foregroundColor(.secondary)
            }
            .navigationBarItems(trailing: Button("Close") { presentationMode.wrappedValue.dismiss() })
        }
    }
}

struct LogbookView: View {
    @Environment(\.presentationMode) var presentationMode
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "book.pages.fill").font(.system(size: 60)).foregroundColor(.purple)
                Text("Hours of Service").font(.title2).fontWeight(.bold)
                Text("Digital logbook compliance tools will go here.").foregroundColor(.secondary)
            }
            .navigationBarItems(trailing: Button("Close") { presentationMode.wrappedValue.dismiss() })
        }
    }
}

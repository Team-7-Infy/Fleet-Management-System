import SwiftUI

struct ProfileHubView: View {
    @State private var showingLogoutAlert = false
    @State private var showingSupportSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                profileHeader
                statsGrid
                quickLinks
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationBarHidden(true)
        .sheet(isPresented: $showingSupportSheet) {
            NavigationView {
                VStack(spacing: 20) {
                    Image(systemName: "headphones").font(.system(size: 48)).foregroundColor(FleetPalette.inProgress)
                    Text("Contact Dispatch").font(.title2).fontWeight(.bold)
                    Text("Call or message your fleet manager for assistance.").foregroundColor(.secondary).multilineTextAlignment(.center)
                }
                .padding()
                .navigationTitle("Support")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 72)).foregroundColor(FleetPalette.inProgress)
            Text("Driver")
                .font(.title2).fontWeight(.bold)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(20)
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(title: "Safety Score", value: "-", icon: "shield.fill", color: FleetPalette.success)
            StatCard(title: "Trips", value: "0", icon: "map.fill", color: FleetPalette.inProgress)
            StatCard(title: "Status", value: "Active", icon: "person.fill.checkmark", color: FleetPalette.success)
            StatCard(title: "Vehicle", value: "-", icon: "truck.box.fill", color: .purple)
        }
    }

    private var quickLinks: some View {
        VStack(spacing: 0) {
            NavigationLink(destination: DocumentCenterView()) {
                LinkRow(icon: "doc.text.fill", title: "Documents", color: FleetPalette.inProgress)
            }
            NavigationLink(destination: PerformanceView()) {
                LinkRow(icon: "chart.bar.fill", title: "Performance", color: FleetPalette.success)
            }
            Button(action: { showingSupportSheet = true }) {
                LinkRow(icon: "headphones", title: "Support", color: FleetPalette.warning)
            }
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title3).foregroundColor(color)
            Text(value).font(.title2).fontWeight(.bold)
            Text(title).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
    }
}

struct LinkRow: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon).foregroundColor(color).frame(width: 28)
            Text(title).font(.subheadline).fontWeight(.medium).foregroundColor(.primary)
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }
}

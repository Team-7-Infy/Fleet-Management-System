import SwiftUI

struct TripDetailView: View {
    let trip: Trip
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    tripHeader
                    routeCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Close") { dismiss() }
                    .fontWeight(.semibold)
            }
        }
    }

    private var tripHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Assigned Route")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    Text(trip.id.uuidString.prefix(8).uppercased())
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.82))
                }
                Spacer()
                Text(trip.status.rawValue.uppercased())
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(trip.status == .pending ? FleetPalette.warning : FleetPalette.success)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Capsule())
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [FleetPalette.inProgress, FleetPalette.secondary],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
    }

    private var routeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Route Details")
                .font(.headline)

            HStack(spacing: 16) {
                VStack(spacing: 0) {
                    Circle().fill(FleetPalette.inProgress).frame(width: 12, height: 12)
                    Rectangle().fill(FleetPalette.inProgress.opacity(0.3)).frame(width: 2, height: 40)
                    Circle().fill(FleetPalette.success).frame(width: 12, height: 12)
                }

                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Origin").font(.caption).foregroundColor(.secondary)
                        Text(trip.startLocation).font(.subheadline).fontWeight(.bold)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Destination").font(.caption).foregroundColor(.secondary)
                        Text(trip.endLocation).font(.subheadline).fontWeight(.bold)
                    }
                }
                Spacer()
            }
        }
        .padding(16)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
    }
}

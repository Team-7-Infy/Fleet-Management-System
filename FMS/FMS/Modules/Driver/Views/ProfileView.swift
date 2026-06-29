import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss

    let driver: Driver
    let user: User?
    let completedTrips: [Trip]
    let onLogout: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                heroSection
                driverInfoSection
                tripHistorySection
                signOutButton
            }
            .padding()
            .padding(.bottom, 24)
        }
        .fleetScreenBackground()
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroSection: some View {
        VStack(spacing: 10) {
            AvatarView(name: displayName, role: .driver, size: 86, imageURL: user?.avatarImageURL)

            VStack(spacing: 4) {
                Text(displayName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(FleetPalette.textPrimary)

                if let email = user?.email {
                    Text(email)
                        .font(.subheadline)
                        .foregroundStyle(FleetPalette.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }

    private var driverInfoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            DashboardSectionTitle("Driver Info")

            GlassPanel {
                VStack(spacing: 12) {
                    InfoRow(title: "License", value: driver.licenceNum.isEmpty ? "Not available" : driver.licenceNum)
                    Divider()
                    InfoRow(title: "Vehicle Type", value: driver.vehicleType.isEmpty ? "Not available" : driver.vehicleType.capitalized)
                    Divider()
                    InfoRow(title: "Status", value: driver.status.title)
                }
            }
        }
    }

    private var tripHistorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            DashboardSectionTitle("Trip History")

            GlassPanel {
                if completedTrips.isEmpty {
                    EmptyStateView(
                        title: "No completed trips",
                        message: "Completed assignments will appear here.",
                        systemImage: "checkmark.circle"
                    )
                } else {
                    VStack(spacing: 12) {
                        ForEach(completedTrips) { trip in
                            VStack(alignment: .leading, spacing: 5) {
                                Text("\(trip.startLocation) to \(trip.endLocation)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(FleetPalette.textPrimary)

                                if let endTime = trip.endTime {
                                    Text("Completed \(endTime, style: .date)")
                                        .font(.caption)
                                        .foregroundStyle(FleetPalette.textSecondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            if trip.id != completedTrips.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    private var signOutButton: some View {
        Button {
            dismiss()
            onLogout()
        } label: {
            Text("Sign Out")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(FleetPalette.danger)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(FleetPalette.surface)
                        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
                )
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }

    private var displayName: String {
        guard let user else { return "Driver" }
        let name = user.displayName
        return name.isEmpty ? "Driver" : name
    }
}

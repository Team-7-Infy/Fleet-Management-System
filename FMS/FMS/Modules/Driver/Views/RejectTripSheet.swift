import SwiftUI

struct RejectTripSheet: View {
    let trip: Trip
    let onSubmit: (String) -> Void

    @State private var reason = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Trip Details")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(FleetPalette.textPrimary)

                        HStack(spacing: 12) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(FleetPalette.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("From")
                                    .font(.caption)
                                    .foregroundStyle(FleetPalette.textSecondary)
                                Text(trip.startLocation)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(FleetPalette.textPrimary)
                            }
                        }

                        HStack(spacing: 12) {
                            Image(systemName: "flag.circle.fill")
                                .foregroundStyle(FleetPalette.danger)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("To")
                                    .font(.caption)
                                    .foregroundStyle(FleetPalette.textSecondary)
                                Text(trip.endLocation)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(FleetPalette.textPrimary)
                            }
                        }

                        HStack(spacing: 12) {
                            Image(systemName: "clock")
                                .foregroundStyle(FleetPalette.textSecondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Scheduled")
                                    .font(.caption)
                                    .foregroundStyle(FleetPalette.textSecondary)
                                Text(trip.startTime, style: .date) + Text(" at ") + Text(trip.startTime, style: .time)
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(FleetPalette.textPrimary)
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(FleetPalette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(FleetPalette.tertiary.opacity(0.55), lineWidth: 1)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Reason for Rejection")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(FleetPalette.textPrimary)

                        TextEditor(text: $reason)
                            .font(.body)
                            .frame(minHeight: 120)
                            .scrollContentBackground(.hidden)
                            .padding(14)
                            .background(FleetPalette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(FleetPalette.tertiary.opacity(0.45), lineWidth: 1)
                            }

                        if reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Please provide a reason for rejecting this trip.")
                                .font(.caption)
                                .foregroundStyle(FleetPalette.danger)
                        }
                    }
                }
                .padding()
            }
            .fleetScreenBackground()
            .navigationTitle("Reject Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(FleetPalette.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        onSubmit(reason)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

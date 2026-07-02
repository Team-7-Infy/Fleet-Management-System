import SwiftUI

struct TripCardView: View {
    let trip: Trip
    let vehicle: Vehicle?
    let onAccept: () -> Void
    let onReject: () -> Void
    let onStart: () -> Void
    let onEnd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 15) {
                TripCardRouteGlyph()

                VStack(alignment: .leading, spacing: 10) {
                    Text(trip.startLocation)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(FleetPalette.textPrimary)
                        .lineLimit(2)

                    Text(trip.endLocation)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(FleetPalette.textPrimary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                StatusDot(text: trip.status.title, color: FleetPalette.tripStatus(trip.status))
            }

            HStack(spacing: 12) {
                if let vehicle {
                    VehicleAssetImage(vehicle: vehicle, width: 48, height: 38, cornerRadius: 10)

                    Text("\(vehicle.make) \(vehicle.model)")
                        .font(.subheadline)
                    Text(vehicle.licencePlate)
                        .font(.caption)
                        .foregroundColor(FleetPalette.textSecondary)
                    if !vehicle.vehicleType.isEmpty {
                        Text(vehicle.vehicleType.capitalized)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(FleetPalette.neutral.opacity(0.12), in: Capsule())
                    }
                }
            }
            .foregroundStyle(FleetPalette.textSecondary)

            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption)
                Text(trip.startTime, style: .date)
                Text("at")
                    .foregroundStyle(FleetPalette.textTertiary)
                Text(trip.startTime, style: .time)
            }
            .font(.caption)
            .foregroundStyle(FleetPalette.textSecondary)

            actionButtons
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FleetPalette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(FleetPalette.tertiary.opacity(0.55), lineWidth: 1)
        }
        .shadow(color: FleetPalette.accent.opacity(0.10), radius: 16, x: 0, y: 9)
    }

    @ViewBuilder
    private var actionButtons: some View {
        switch trip.status {
        case .pending:
            HStack(spacing: 12) {
                Button(action: onAccept) {
                    Label("Accept", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(FleetPalette.success)

                Button(action: onReject) {
                    Label("Reject", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(FleetPalette.danger)
            }

        case .accepted:
            Button(action: onStart) {
                Label("Start Trip", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(FleetPalette.accent)

        case .inProgress:
            Button(action: onEnd) {
                Label("End Trip", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(FleetPalette.warning)

        case .rejectionPending:
            HStack(spacing: 8) {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundStyle(FleetPalette.warning)
                Text("Awaiting fleet manager approval")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(FleetPalette.warning)
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(FleetPalette.warning.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

        case .rejected, .completed:
            EmptyView()
        }
    }
}

private struct TripCardRouteGlyph: View {
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "mappin.circle.fill")
                .font(.title2.weight(.bold))
                .foregroundStyle(FleetPalette.accent)

            VStack(spacing: 3) {
                ForEach(0..<4, id: \.self) { _ in
                    Circle()
                        .fill(FleetPalette.accent.opacity(0.62))
                        .frame(width: 4, height: 4)
                }
            }

            Image(systemName: "mappin.circle.fill")
                .font(.title2.weight(.bold))
                .foregroundStyle(FleetPalette.danger)
        }
        .frame(width: 34)
    }
}

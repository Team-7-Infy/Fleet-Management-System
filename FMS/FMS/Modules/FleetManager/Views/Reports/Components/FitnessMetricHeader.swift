import SwiftUI

struct FitnessMetricHeader: View {
    let label: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(FleetPalette.accent)

            Text(value)
                .font(.system(size: 38, weight: .black, design: .rounded).monospacedDigit())
                .foregroundStyle(FleetPalette.textPrimary)

            Text(subtitle)
                .font(.footnote.weight(.medium))
                .foregroundStyle(FleetPalette.textSecondary)
        }
    }
}


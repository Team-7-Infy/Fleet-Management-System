import SwiftUI

struct FitnessMetricHeader: View {
    let label: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .foregroundStyle(FleetPalette.textPrimary)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
    }
}

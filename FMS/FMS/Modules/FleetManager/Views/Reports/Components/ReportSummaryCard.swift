import SwiftUI

struct ReportSummaryCard: View {
    let title: String
    let primaryValue: String
    let primaryLabel: String
    let secondaryValue: String
    let secondaryLabel: String
    let tint: Color
    let trendValue: String?
    let trendIsPositive: Bool?

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(FleetPalette.textSecondary)
                Spacer().frame(height: 2)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(primaryValue)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(tint)
                    Text(primaryLabel)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(FleetPalette.textSecondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(secondaryValue)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(FleetPalette.textPrimary)
                    Text(secondaryLabel)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(FleetPalette.textSecondary)
                }

                if let trend = trendValue, let isPositive = trendIsPositive {
                    HStack(spacing: 3) {
                        Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 9, weight: .black))
                        Text(trend)
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(isPositive ? FleetPalette.success : FleetPalette.danger)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(FleetPalette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(FleetPalette.tertiary.opacity(0.15), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 4)
    }
}

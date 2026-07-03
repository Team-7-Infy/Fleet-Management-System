import SwiftUI

struct PeriodFilterPicker: View {
    @Binding var selectedPeriod: PeriodPreset

    var body: some View {
        HStack(spacing: 6) {
            ForEach(PeriodPreset.allCases) { period in
                Button {
                    withAnimation(.snappy) { selectedPeriod = period }
                } label: {
                    Text(period.rawValue)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(selectedPeriod == period ? .white : FleetPalette.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            selectedPeriod == period
                                ? FleetPalette.accent
                                : FleetPalette.tertiary.opacity(0.1),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(FleetPalette.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(FleetPalette.tertiary.opacity(0.15), lineWidth: 1)
        }
    }
}

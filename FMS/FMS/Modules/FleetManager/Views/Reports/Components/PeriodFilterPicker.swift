import SwiftUI

struct PeriodFilterPicker: View {
    @Binding var selectedPeriod: PeriodPreset
    @Namespace private var activeTabNamespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(PeriodPreset.allCases) { period in
                let isSelected = selectedPeriod == period
                Text(period.rawValue)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : FleetPalette.textSecondary)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [FleetPalette.accent, FleetPalette.accent.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .matchedGeometryEffect(id: "activePeriodTab", in: activeTabNamespace)
                                .shadow(color: FleetPalette.accent.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            selectedPeriod = period
                        }
                        let generator = UISelectionFeedbackGenerator()
                        generator.selectionChanged()
                    }
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(FleetPalette.surface)
                .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 3)
        )
        .overlay {
            Capsule()
                .stroke(FleetPalette.tertiary.opacity(0.15), lineWidth: 1)
        }
    }
}

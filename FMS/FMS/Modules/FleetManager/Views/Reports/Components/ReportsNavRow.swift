import SwiftUI

struct ReportsNavRow: View {
    var action: (() -> Void)?

    var body: some View {
        Button(action: { action?() }) {
            HStack {
                Label("Reports and Analytics", systemImage: "chart.bar.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(FleetPalette.accent)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(FleetPalette.accent)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FleetPalette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

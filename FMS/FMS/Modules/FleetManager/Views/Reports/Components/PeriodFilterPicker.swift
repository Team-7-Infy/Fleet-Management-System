import SwiftUI

struct PeriodFilterPicker: View {
    @Binding var selectedPeriod: PeriodPreset

    var body: some View {
        Picker("Timeframe", selection: $selectedPeriod) {
            ForEach(PeriodPreset.allCases) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .buttonBorderShape(.capsule)
    }
}

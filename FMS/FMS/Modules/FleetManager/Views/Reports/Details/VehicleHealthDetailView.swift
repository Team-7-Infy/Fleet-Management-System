import SwiftUI
import Charts

struct VehicleHealthDetailView: View {
    @ObservedObject var reportsViewModel: ReportsViewModel
    @ObservedObject var vehiclesViewModel: VehicleViewModel
    @ObservedObject var maintenanceViewModel: MaintenanceViewModel

    @State private var localPeriod: PeriodPreset = .oneMonth

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeader(title: "Vehicle Health", subtitle: "Score breakdown by vehicle")
                PeriodFilterPicker(selectedPeriod: $localPeriod)
                    .padding(.horizontal, 4)
                    .onChange(of: localPeriod) { _, new in
                        reportsViewModel.selectedPeriod = new
                    }

                healthSummaryGrid
                healthScoreChart
                healthList
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .fleetScreenBackground()
        .navigationTitle("Vehicle Health")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { localPeriod = reportsViewModel.selectedPeriod }
    }

    private var healthSummaryGrid: some View {
        let scores = reportsViewModel.vehicleHealthScores
        let avg = scores.isEmpty ? 0 : scores.map(\.score).reduce(0, +) / scores.count
        let good = scores.filter { $0.score >= 70 }.count
        let fair = scores.filter { $0.score >= 40 && $0.score < 70 }.count
        let poor = scores.filter { $0.score < 40 }.count

        return LazyVGrid(columns: FleetPalette.twoColumnGrid, spacing: 12) {
            DashboardMetricCard(title: "Avg Score", systemImage: "heart.fill", tint: FleetPalette.danger, metrics: [("Score", "\(avg)")])
            DashboardMetricCard(title: "Good (70+)", systemImage: "checkmark.circle", tint: FleetPalette.success, metrics: [("Count", "\(good)")])
            DashboardMetricCard(title: "Fair (40-69)", systemImage: "exclamationmark.circle", tint: FleetPalette.warning, metrics: [("Count", "\(fair)")])
            DashboardMetricCard(title: "Poor (<40)", systemImage: "xmark.circle", tint: FleetPalette.danger, metrics: [("Count", "\(poor)")])
        }
    }

    private var healthScoreChart: some View {
        GlassPanel(hasBorder: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text("HEALTH SCORES")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(FleetPalette.textSecondary)

                let data = reportsViewModel.vehicleHealthScores
                if data.isEmpty {
                    Text("No vehicle data")
                        .font(.subheadline).foregroundStyle(FleetPalette.textSecondary)
                        .frame(maxWidth: .infinity).frame(height: 160)
                } else {
                    Chart(data, id: \.vehicle.id) { item in
                        BarMark(
                            x: .value("Vehicle", item.vehicle.licencePlate),
                            y: .value("Score", item.score)
                        )
                        .foregroundStyle(by: .value("Band", scoreBand(item.score)))
                    }
                    .chartForegroundStyleScale([
                        "Good": FleetPalette.success,
                        "Fair": FleetPalette.warning,
                        "Poor": FleetPalette.danger
                    ])
                    .chartXAxis { AxisMarks { AxisValueLabel() } }
                    .chartYAxis { AxisMarks { AxisValueLabel() } }
                    .frame(height: 180)
                }
            }
        }
    }

    private var healthList: some View {
        GlassPanel(hasBorder: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text("VEHICLE HEALTH DETAILS")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(FleetPalette.textSecondary)

                let data = reportsViewModel.vehicleHealthScores
                if data.isEmpty {
                    Text("No data")
                        .font(.subheadline).foregroundStyle(FleetPalette.textSecondary)
                } else {
                    ForEach(data, id: \.vehicle.id) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.vehicle.licencePlate)
                                    .font(.subheadline.weight(.bold)).foregroundStyle(FleetPalette.textPrimary)
                                Text("\(item.vehicle.make) \(item.vehicle.model)")
                                    .font(.caption).foregroundStyle(FleetPalette.textSecondary)
                            }
                            Spacer()
                            Text("\(item.score)")
                                .font(.title3.weight(.heavy).monospacedDigit())
                                .foregroundStyle(scoreColor(item.score))
                        }
                        Divider()
                    }
                }
            }
        }
    }

    private func scoreBand(_ score: Int) -> String {
        score >= 70 ? "Good" : score >= 40 ? "Fair" : "Poor"
    }

    private func scoreColor(_ score: Int) -> Color {
        score >= 70 ? FleetPalette.success : score >= 40 ? FleetPalette.warning : FleetPalette.danger
    }
}

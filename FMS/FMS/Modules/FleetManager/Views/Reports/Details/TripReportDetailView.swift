import SwiftUI
import Charts

struct TripReportDetailView: View {
    @ObservedObject var tripsViewModel: ReportsViewModel
    @ObservedObject var vehiclesViewModel: VehicleViewModel
    @ObservedObject var usersViewModel: UserManagementViewModel

    @State private var localPeriod: PeriodPreset = .oneMonth

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeader(title: "Trip Report", subtitle: "Detailed trip performance")
                PeriodFilterPicker(selectedPeriod: $localPeriod)
                    .padding(.horizontal, 4)
                    .onChange(of: localPeriod) { _, new in
                        tripsViewModel.selectedPeriod = new
                    }

                summaryGrid
                weeklyChart
                punctualitySection
                fuelExpenditureSection
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .fleetScreenBackground()
        .navigationTitle("Trip Report")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            localPeriod = tripsViewModel.selectedPeriod
        }
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: FleetPalette.twoColumnGrid, spacing: 12) {
            DashboardMetricCard(title: "Total Trips", systemImage: "number", tint: FleetPalette.accent, metrics: [("Count", "\(tripsViewModel.totalFilteredTrips)")])
            DashboardMetricCard(title: "Completed", systemImage: "checkmark.circle", tint: FleetPalette.success, metrics: [("Rate", "\(Int(tripsViewModel.completionRate * 100))%")])
            DashboardMetricCard(title: "Total Cost", systemImage: "indianrupeesign", tint: FleetPalette.warning, metrics: [("Amount", tripsViewModel.filteredTripCostTotal.formatted(.currency(code: "INR")))])

            let avgCost = tripsViewModel.totalFilteredCompletedTrips > 0
                ? tripsViewModel.filteredTripCostTotal / Double(tripsViewModel.totalFilteredCompletedTrips)
                : 0
            DashboardMetricCard(title: "Avg Cost/Trip", systemImage: "chart.bar.fill", tint: FleetPalette.tertiary, metrics: [("Per Trip", avgCost.formatted(.currency(code: "INR")))])
        }
    }

    private var weeklyChart: some View {
        GlassPanel(hasBorder: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text("TRIPS BY WEEK")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(FleetPalette.textSecondary)

                let data = tripsViewModel.filteredTripsByWeek
                if data.isEmpty {
                    Text("No trip data")
                        .font(.subheadline)
                        .foregroundStyle(FleetPalette.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                } else {
                    Chart(data, id: \.weekStart) { item in
                        BarMark(
                            x: .value("Week", item.weekStart, unit: .weekOfYear),
                            y: .value("Trips", item.count)
                        )
                        .foregroundStyle(FleetPalette.accent.gradient)
                    }
                    .chartXAxis { AxisMarks(values: .stride(by: .month)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                    } }
                    .chartYAxis { AxisMarks { AxisValueLabel() } }
                    .frame(height: 160)
                }
            }
        }
    }

    private var punctualitySection: some View {
        GlassPanel(hasBorder: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text("TRIP PUNCTUALITY")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(FleetPalette.textSecondary)

                let onTime = tripsViewModel.onTimeTrips.prefix(5)
                let delayed = tripsViewModel.delayedTrips.prefix(5)

                if onTime.isEmpty && delayed.isEmpty {
                    Text("No completed trips to evaluate")
                        .font(.subheadline)
                        .foregroundStyle(FleetPalette.textSecondary)
                } else {
                    if onTime.isEmpty == false {
                        Text("Most On-Time").font(.subheadline.weight(.bold)).foregroundStyle(FleetPalette.success)
                        ForEach(onTime, id: \.trip.id) { item in
                            HStack {
                                Text("\(item.trip.startLocation) → \(item.trip.endLocation)")
                                    .font(.caption).foregroundStyle(FleetPalette.textPrimary).lineLimit(1)
                                Spacer()
                                Text("\(Int(abs(item.deviation) / 60)) min early")
                                    .font(.caption.weight(.bold)).foregroundStyle(FleetPalette.success)
                            }
                        }
                    }
                    if delayed.isEmpty == false {
                        Divider()
                        Text("Most Delayed").font(.subheadline.weight(.bold)).foregroundStyle(FleetPalette.danger)
                        ForEach(delayed, id: \.trip.id) { item in
                            HStack {
                                Text("\(item.trip.startLocation) → \(item.trip.endLocation)")
                                    .font(.caption).foregroundStyle(FleetPalette.textPrimary).lineLimit(1)
                                Spacer()
                                Text("\(Int(item.deviation / 60)) min late")
                                    .font(.caption.weight(.bold)).foregroundStyle(FleetPalette.danger)
                            }
                        }
                    }
                }
            }
        }
    }

    private var fuelExpenditureSection: some View {
        GlassPanel(hasBorder: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text("FUEL EXPENDITURE")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(FleetPalette.textSecondary)

                let top = tripsViewModel.topTripsByFuelCost.prefix(5)
                let bottom = tripsViewModel.bottomTripsByFuelCost.prefix(5)

                if top.isEmpty {
                    Text("No fuel data recorded")
                        .font(.subheadline)
                        .foregroundStyle(FleetPalette.textSecondary)
                } else {
                    Text("Highest Fuel Cost").font(.subheadline.weight(.bold)).foregroundStyle(FleetPalette.warning)
                    ForEach(top, id: \.trip.id) { item in
                        HStack {
                            Text("\(item.trip.startLocation) → \(item.trip.endLocation)")
                                .font(.caption).foregroundStyle(FleetPalette.textPrimary).lineLimit(1)
                            Spacer()
                            Text(item.cost.formatted(.currency(code: "INR")))
                                .font(.caption.weight(.bold)).foregroundStyle(FleetPalette.warning)
                        }
                    }

                    Divider()

                    Text("Lowest Fuel Cost").font(.subheadline.weight(.bold)).foregroundStyle(FleetPalette.success)
                    ForEach(bottom, id: \.trip.id) { item in
                        HStack {
                            Text("\(item.trip.startLocation) → \(item.trip.endLocation)")
                                .font(.caption).foregroundStyle(FleetPalette.textPrimary).lineLimit(1)
                            Spacer()
                            Text(item.cost.formatted(.currency(code: "INR")))
                                .font(.caption.weight(.bold)).foregroundStyle(FleetPalette.success)
                        }
                    }
                }
            }
        }
    }
}

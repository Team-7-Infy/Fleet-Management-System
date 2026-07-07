import SwiftUI
import Charts

struct DriverPerformanceDetailView: View {
    @ObservedObject var reportsViewModel: ReportsViewModel
    @ObservedObject var usersViewModel: UserManagementViewModel

    @State private var localPeriod: PeriodPreset = .twoMonths

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeader(title: "Driver Performance", subtitle: "Trip stats per driver")
                PeriodFilterPicker(selectedPeriod: $localPeriod)
                    .padding(.horizontal, 4)
                    .onChange(of: localPeriod) { _, new in
                        reportsViewModel.selectedPeriod = new
                    }

                driverSummaryGrid
                driverTripChart
                driverList
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .fleetScreenBackground()
        .navigationTitle("Driver Perf.")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ReportExportToolbarItem(reportType: .driverPerformance, viewModel: reportsViewModel)
            }
        }
        .onAppear { localPeriod = reportsViewModel.selectedPeriod }
    }

    private var driverSummaryGrid: some View {
        let active = reportsViewModel.driverPerformance.filter { $0.tripCount > 0 }.count
        return LazyVGrid(columns: FleetPalette.twoColumnGrid, spacing: 12) {
            DashboardMetricCard(title: "Active Drivers", systemImage: "person.2.fill", tint: FleetPalette.accent, metrics: [("Count", "\(active)")])
            DashboardMetricCard(title: "Total Trips", systemImage: "point.topleft.down.curvedto.point.bottomright.up", tint: FleetPalette.success, metrics: [("Count", "\(reportsViewModel.totalFilteredTrips)")])
            DashboardMetricCard(title: "Avg Score", systemImage: "star.fill", tint: FleetPalette.warning, metrics: [("Score", "\(reportsViewModel.averageDriverScore)")])
            DashboardMetricCard(title: "Total Drivers", systemImage: "person.3.fill", tint: FleetPalette.tertiary, metrics: [("Count", "\(usersViewModel.drivers.count)")])
        }
    }

    private var driverTripChart: some View {
        GlassPanel(hasBorder: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text("TRIPS PER DRIVER")
                    .font(.caption).bold()
                    .foregroundStyle(FleetPalette.textSecondary)

                let data = reportsViewModel.driverPerformance.prefix(8)
                if data.isEmpty {
                    Text("No driver trip data")
                        .font(.subheadline).foregroundStyle(FleetPalette.textSecondary)
                        .frame(maxWidth: .infinity).frame(height: 160)
                } else {
                    Chart(data, id: \.driver.id) { item in
                        BarMark(
                            x: .value("Trips", item.tripCount),
                            y: .value("Driver", item.user?.displayName ?? "Driver")
                        )
                        .foregroundStyle(FleetPalette.tertiary.gradient)
                    }
                    .chartXAxis { AxisMarks { AxisValueLabel() } }
                    .chartYAxis { AxisMarks { AxisValueLabel() } }
                    .frame(height: 200)
                }
            }
        }
    }

    private var driverList: some View {
        GlassPanel(hasBorder: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text("DRIVER TRIP BREAKDOWN")
                    .font(.caption).bold()
                    .foregroundStyle(FleetPalette.textSecondary)

                let data = reportsViewModel.driverPerformance
                if data.isEmpty {
                    Text("No data")
                        .font(.subheadline).foregroundStyle(FleetPalette.textSecondary)
                } else {
                    ForEach(data, id: \.driver.id) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.user?.displayName ?? "Unknown")
                                    .font(.subheadline).bold().foregroundStyle(FleetPalette.textPrimary)
                                Text(item.driver.licenceNum)
                                    .font(.caption).foregroundStyle(FleetPalette.textSecondary)
                            }
                            Spacer()
                            Text("\(item.tripCount) trips")
                                .font(.subheadline).bold().foregroundStyle(FleetPalette.accent)
                        }
                        Divider()
                    }
                }
            }
        }
    }
}

import SwiftUI
import Charts

struct FleetUtilizationDetailView: View {
    @ObservedObject var reportsViewModel: ReportsViewModel
    @ObservedObject var vehiclesViewModel: VehicleViewModel
    @ObservedObject var usersViewModel: UserManagementViewModel

    @State private var localPeriod: PeriodPreset = .oneMonth

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeader(title: "Fleet Utilization", subtitle: "Vehicle and driver usage")
                PeriodFilterPicker(selectedPeriod: $localPeriod)
                    .padding(.horizontal, 4)
                    .onChange(of: localPeriod) { _, new in
                        reportsViewModel.selectedPeriod = new
                    }

                fleetSummaryGrid
                vehicleUtilizationChart
                vehicleUtilizationList
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .fleetScreenBackground()
        .navigationTitle("Utilization")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { localPeriod = reportsViewModel.selectedPeriod }
    }

    private var fleetSummaryGrid: some View {
        LazyVGrid(columns: FleetPalette.twoColumnGrid, spacing: 12) {
            DashboardMetricCard(title: "Total Vehicles", systemImage: "car.2.fill", tint: FleetPalette.accent, metrics: [("Count", "\(vehiclesViewModel.vehicles.count)")])

            let active = vehiclesViewModel.activeVehicles.count
            DashboardMetricCard(title: "Active", systemImage: "checkmark.circle", tint: FleetPalette.success, metrics: [("Count", "\(active)")])

            let maint = vehiclesViewModel.maintenanceVehicles.count
            DashboardMetricCard(title: "In Maintenance", systemImage: "wrench.fill", tint: FleetPalette.warning, metrics: [("Count", "\(maint)")])

            let driversOnTrips = reportsViewModel.driverPerformance.count
            DashboardMetricCard(title: "Drivers on Trip", systemImage: "person.fill", tint: FleetPalette.tertiary, metrics: [("Count", "\(driversOnTrips)")])
        }
    }

    private var vehicleUtilizationChart: some View {
        GlassPanel(hasBorder: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text("VEHICLE USAGE (TOP 8)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(FleetPalette.textSecondary)

                let data = reportsViewModel.vehicleUtilization.prefix(8)
                if data.isEmpty {
                    Text("No vehicle usage data")
                        .font(.subheadline).foregroundStyle(FleetPalette.textSecondary)
                        .frame(maxWidth: .infinity).frame(height: 160)
                } else {
                    Chart(data, id: \.vehicle.id) { item in
                        BarMark(
                            x: .value("Trips", item.tripCount),
                            y: .value("Vehicle", item.vehicle.licencePlate)
                        )
                        .foregroundStyle(FleetPalette.success.gradient)
                    }
                    .chartXAxis { AxisMarks { AxisValueLabel() } }
                    .chartYAxis { AxisMarks { AxisValueLabel() } }
                    .frame(height: 200)
                }
            }
        }
    }

    private var vehicleUtilizationList: some View {
        GlassPanel(hasBorder: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text("VEHICLE TRIP COUNTS")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(FleetPalette.textSecondary)

                let data = reportsViewModel.vehicleUtilization
                if data.isEmpty {
                    Text("No data")
                        .font(.subheadline).foregroundStyle(FleetPalette.textSecondary)
                } else {
                    ForEach(data, id: \.vehicle.id) { item in
                        HStack {
                            Text(item.vehicle.licencePlate)
                                .font(.subheadline.weight(.bold)).foregroundStyle(FleetPalette.textPrimary)
                            Text("\(item.vehicle.make) \(item.vehicle.model)")
                                .font(.caption).foregroundStyle(FleetPalette.textSecondary)
                            Spacer()
                            Text("\(item.tripCount) trips")
                                .font(.subheadline.weight(.bold)).foregroundStyle(FleetPalette.accent)
                        }
                        Divider()
                    }
                }
            }
        }
    }
}

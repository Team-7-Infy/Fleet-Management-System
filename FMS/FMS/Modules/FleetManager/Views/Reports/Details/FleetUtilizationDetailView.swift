import SwiftUI
import Charts

struct FleetUtilizationDetailView: View {
    @ObservedObject var reportsViewModel: ReportsViewModel
    @ObservedObject var vehiclesViewModel: VehicleViewModel
    @ObservedObject var usersViewModel: UserManagementViewModel
    @ObservedObject var maintenanceViewModel: MaintenanceViewModel

    @State private var localPeriod: PeriodPreset = .twoMonths

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PeriodFilterPicker(selectedPeriod: $localPeriod)
                    .padding(.horizontal, 4)
                    .onChange(of: localPeriod) { _, new in
                        reportsViewModel.selectedPeriod = new
                    }

                utilizationChart
                fleetSummaryGrid
                vehicleUtilizationList
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .fleetScreenBackground()
        .navigationTitle("Utilization")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ReportExportToolbarItem(reportType: .fleetUtilization, viewModel: reportsViewModel)
            }
        }
        .onAppear { localPeriod = reportsViewModel.selectedPeriod }
    }

    private var fleetSummaryGrid: some View {
        let active = vehiclesViewModel.activeVehicles.count
        let maint = vehiclesViewModel.maintenanceVehicles.count
        let driversOnTrips = reportsViewModel.driverPerformance.count

        return GlassPanel(hasBorder: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("UTILIZATION SUMMARY")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: FleetPalette.twoColumnGrid, alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(vehiclesViewModel.vehicles.count)")
                            .font(.title3).bold()
                            .foregroundStyle(FleetPalette.textPrimary)
                            .frame(minHeight: 26, alignment: .bottom)
                        Text("Total Vehicles")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(active)")
                            .font(.title3).bold()
                            .foregroundStyle(FleetPalette.textPrimary)
                            .frame(minHeight: 26, alignment: .bottom)
                        Text("Active")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(maint)")
                            .font(.title3).bold()
                            .foregroundStyle(FleetPalette.textPrimary)
                        Text("In Maintenance")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(driversOnTrips)")
                            .font(.title3).bold()
                            .foregroundStyle(FleetPalette.textPrimary)
                        Text("Drivers on Trip")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(4)
        }
    }

    private var utilizationChart: some View {
        GlassPanel(hasBorder: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text("FLEET UTILIZATION (MONTHLY)")
                    .font(.caption).bold()
                    .foregroundStyle(FleetPalette.textSecondary)

                let data = reportsViewModel.fleetUtilizationByMonth

                if data.allSatisfy({ $0.vehiclesUsed == 0 }) {
                    ContentUnavailableView(
                        "No Utilization Data",
                        systemImage: "car.2.fill",
                        description: Text("No vehicle usage data for this period.")
                    )
                    .frame(height: 180)
                } else {
                    FitnessLineChart(
                        data: data,
                        totalVehicles: reportsViewModel.totalVehiclesCount,
                        color: FleetPalette.success
                    )
                }
            }
        }
    }

    private var vehicleUtilizationList: some View {
        GlassPanel(hasBorder: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text("VEHICLE TRIP COUNTS")
                    .font(.caption).bold()
                    .foregroundStyle(FleetPalette.textSecondary)

                let data = reportsViewModel.vehicleUtilization
                if data.isEmpty {
                    Text("No data")
                        .font(.subheadline).foregroundStyle(FleetPalette.textSecondary)
                } else {
                    ForEach(data, id: \.vehicle.id) { item in
                        NavigationLink {
                            ManagerVehicleDetailView(
                                vehicle: item.vehicle,
                                viewModel: vehiclesViewModel,
                                usersViewModel: usersViewModel,
                                maintenanceViewModel: maintenanceViewModel,
                                openMaintenanceRequest: { _ in }
                            )
                        } label: {
                            HStack {
                                Text(item.vehicle.licencePlate)
                                    .font(.subheadline).bold().foregroundStyle(FleetPalette.textPrimary)
                                Text("\(item.vehicle.make) \(item.vehicle.model)")
                                    .font(.caption).foregroundStyle(FleetPalette.textSecondary)
                                Spacer()
                                Text("\(item.tripCount) trips")
                                    .font(.subheadline).bold().foregroundStyle(FleetPalette.accent)
                            }
                        }
                        Divider()
                    }
                }
            }
        }
    }
}

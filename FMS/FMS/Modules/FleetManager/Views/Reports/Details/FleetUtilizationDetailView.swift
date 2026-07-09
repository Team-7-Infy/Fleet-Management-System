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

        return FitnessCategoryCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("UTILIZATION SUMMARY")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(FleetPalette.accent)

                LazyVGrid(columns: FleetPalette.twoColumnGrid, spacing: 14) {
                    summaryGridCell(title: "Total Vehicles", value: "\(vehiclesViewModel.vehicles.count)", icon: "car.2.fill", color: FleetPalette.accent)
                    summaryGridCell(title: "Active", value: "\(active)", icon: "checkmark.circle.fill", color: FleetPalette.success)
                    summaryGridCell(title: "In Maintenance", value: "\(maint)", icon: "wrench.and.screwdriver.fill", color: FleetPalette.warning)
                    summaryGridCell(title: "Drivers on Trip", value: "\(driversOnTrips)", icon: "person.fill.badge.plus", color: .purple)
                }
            }
        }
    }

    private func summaryGridCell(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.08), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(FleetPalette.textPrimary)
                    .lineLimit(1)
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(FleetPalette.textSecondary)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FleetPalette.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(FleetPalette.tertiary.opacity(0.1), lineWidth: 1)
        }
    }

    private var utilizationChart: some View {
        FitnessCategoryCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("FLEET UTILIZATION (MONTHLY)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(FleetPalette.accent)

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
        FitnessCategoryCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("VEHICLE TRIP COUNTS")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(FleetPalette.accent)
                    .padding(.bottom, 4)

                let data = reportsViewModel.vehicleUtilization
                if data.isEmpty {
                    Text("No data")
                        .font(.subheadline).foregroundStyle(FleetPalette.textSecondary)
                } else {
                    VStack(spacing: 8) {
                        ForEach(data, id: \.vehicle.id) { item in
                            vehicleRow(item: item)
                        }
                    }
                }
            }
        }
    }

    private func vehicleRow(item: (vehicle: Vehicle, tripCount: Int)) -> some View {
        NavigationLink {
            ManagerVehicleDetailView(
                vehicle: item.vehicle,
                viewModel: vehiclesViewModel,
                usersViewModel: usersViewModel,
                maintenanceViewModel: maintenanceViewModel,
                openMaintenanceRequest: { _ in }
            )
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "car.fill")
                    .font(.title3)
                    .foregroundStyle(FleetPalette.accent)
                    .frame(width: 36, height: 36)
                    .background(FleetPalette.accent.opacity(0.08), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.vehicle.licencePlate)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(FleetPalette.textPrimary)
                    Text("\(item.vehicle.make) \(item.vehicle.model)")
                        .font(.caption)
                        .foregroundStyle(FleetPalette.textSecondary)
                }

                Spacer(minLength: 8)

                HStack(spacing: 4) {
                    Text("\(item.tripCount) trips")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(FleetPalette.accent)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(FleetPalette.textSecondary)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(FleetPalette.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(FleetPalette.tertiary.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

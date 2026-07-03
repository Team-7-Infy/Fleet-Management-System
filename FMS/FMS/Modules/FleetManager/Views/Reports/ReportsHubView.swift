import SwiftUI
import Charts

struct ReportsHubView: View {
    @StateObject private var viewModel: ReportsViewModel
    @ObservedObject var vehiclesViewModel: VehicleViewModel
    @ObservedObject var usersViewModel: UserManagementViewModel
    @ObservedObject var maintenanceViewModel: MaintenanceViewModel

    init(
        tripsViewModel: TripManagementViewModel,
        vehiclesViewModel: VehicleViewModel,
        maintenanceViewModel: MaintenanceViewModel,
        usersViewModel: UserManagementViewModel
    ) {
        _viewModel = StateObject(wrappedValue: ReportsViewModel(
            tripsViewModel: tripsViewModel,
            vehiclesViewModel: vehiclesViewModel,
            maintenanceViewModel: maintenanceViewModel,
            usersViewModel: usersViewModel
        ))
        self.vehiclesViewModel = vehiclesViewModel
        self.usersViewModel = usersViewModel
        self.maintenanceViewModel = maintenanceViewModel
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeader(title: "Reports & Analytics", subtitle: "Fleet performance overview")
                PeriodFilterPicker(selectedPeriod: $viewModel.selectedPeriod)
                    .padding(.horizontal, 4)
                summaryRow
                tripReportCard
                maintenanceReportCard
                fleetUtilizationCard
                driverPerformanceCard
                vehicleHealthCard
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .fleetScreenBackground()
        .navigationTitle("Reports")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Summary Bar

    private var summaryRow: some View {
        HStack(spacing: 8) {
            summaryBadge(value: "\(viewModel.totalFilteredTrips)", label: "Trips", color: FleetPalette.accent)
            summaryBadge(value: "\(viewModel.totalFilteredCompletedTrips)", label: "Completed", color: FleetPalette.success)
            summaryBadge(value: viewModel.filteredTripCostTotal.formatted(.currency(code: "INR")), label: "Trip Cost", color: FleetPalette.warning)
            summaryBadge(value: viewModel.maintenanceCostTotal.formatted(.currency(code: "INR")), label: "Maint.", color: FleetPalette.danger)
        }
    }

    private func summaryBadge(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(FleetPalette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(FleetPalette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(FleetPalette.tertiary.opacity(0.12), lineWidth: 1)
        }
    }

    // MARK: - Trip Report

    private var tripReportCard: some View {
        NavigationLink {
            TripReportDetailView(
                tripsViewModel: viewModel,
                vehiclesViewModel: vehiclesViewModel,
                usersViewModel: usersViewModel
            )
        } label: {
            ReportCategoryCard(title: "Trip Report", systemImage: "point.topleft.down.curvedto.point.bottomright.up", tint: FleetPalette.accent) {
                VStack(spacing: 12) {
                    tripChart
                    HStack(spacing: 0) {
                        statItem(value: "\(viewModel.totalFilteredTrips)", label: "Total Trips")
                        Divider().frame(height: 30)
                        statItem(value: viewModel.totalFilteredCompletedTrips > 0 ? "\(Int(viewModel.completionRate * 100))%" : "0%", label: "Completion")
                        Divider().frame(height: 30)
                        statItem(value: viewModel.filteredTripCostTotal.formatted(.currency(code: "INR")), label: "Total Cost")
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var tripChart: some View {
        let data = viewModel.filteredTripsByWeek
        if data.isEmpty {
            emptyChart("No trip data for this period")
        } else {
            Chart(data, id: \.weekStart) { item in
                BarMark(
                    x: .value("Week", item.weekStart, unit: .weekOfYear),
                    y: .value("Trips", item.count)
                )
                .foregroundStyle(FleetPalette.accent.gradient)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
            .chartYAxis { AxisMarks { AxisValueLabel() } }
            .frame(height: 140)
        }
    }

    // MARK: - Maintenance Report

    private var maintenanceReportCard: some View {
        NavigationLink {
            MaintenanceReportDetailView(
                reportsViewModel: viewModel,
                maintenanceViewModel: maintenanceViewModel,
                usersViewModel: usersViewModel
            )
        } label: {
            ReportCategoryCard(title: "Maintenance Report", systemImage: "wrench.and.screwdriver", tint: FleetPalette.warning) {
                VStack(spacing: 12) {
                    maintenanceCostChart
                    HStack(spacing: 0) {
                        statItem(value: "\(viewModel.filteredCompletedTasks.count)", label: "Completed")
                        Divider().frame(height: 30)
                        statItem(value: viewModel.maintenanceCostTotal.formatted(.currency(code: "INR")), label: "Total Cost")
                        Divider().frame(height: 30)
                        statItem(value: viewModel.maintenanceLabourTotal.formatted(.currency(code: "INR")), label: "Labour")
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var maintenanceCostChart: some View {
        let completed = viewModel.filteredCompletedTasks.prefix(10)
        if completed.isEmpty {
            emptyChart("No completed work orders")
        } else {
            Chart(completed, id: \.id) { task in
                BarMark(
                    x: .value("Task", task.displayTitle),
                    y: .value("Cost", task.totalCost ?? 0)
                )
                .foregroundStyle(FleetPalette.warning.gradient)
            }
            .chartXAxis { AxisMarks { AxisValueLabel(orientation: .vertical) } }
            .chartYAxis { AxisMarks { AxisValueLabel() } }
            .frame(height: 140)
        }
    }

    // MARK: - Fleet Utilization

    private var fleetUtilizationCard: some View {
        NavigationLink {
            FleetUtilizationDetailView(
                reportsViewModel: viewModel,
                vehiclesViewModel: vehiclesViewModel,
                usersViewModel: usersViewModel
            )
        } label: {
            ReportCategoryCard(title: "Fleet Utilization", systemImage: "car.2.fill", tint: FleetPalette.success) {
                VStack(spacing: 12) {
                    utilizationChart
                    HStack(spacing: 0) {
                        let activeV = vehiclesViewModel.activeVehicles.count
                        let maintV = vehiclesViewModel.maintenanceVehicles.count
                        statItem(value: "\(vehiclesViewModel.vehicles.count)", label: "Total Vehicles")
                        Divider().frame(height: 30)
                        statItem(value: "\(activeV)", label: "Active")
                        Divider().frame(height: 30)
                        statItem(value: "\(maintV)", label: "In Maint.")
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var utilizationChart: some View {
        let data = viewModel.vehicleUtilization.prefix(5)
        if data.isEmpty {
            emptyChart("No vehicle usage data")
        } else {
            Chart(data, id: \.vehicle.id) { item in
                BarMark(
                    x: .value("Vehicle", item.vehicle.licencePlate),
                    y: .value("Trips", item.tripCount)
                )
                .foregroundStyle(FleetPalette.success.gradient)
            }
            .chartXAxis { AxisMarks { AxisValueLabel() } }
            .chartYAxis { AxisMarks { AxisValueLabel() } }
            .frame(height: 140)
        }
    }

    // MARK: - Driver Performance

    private var driverPerformanceCard: some View {
        NavigationLink {
            DriverPerformanceDetailView(
                reportsViewModel: viewModel,
                usersViewModel: usersViewModel
            )
        } label: {
            ReportCategoryCard(title: "Driver Performance", systemImage: "person.2.fill", tint: FleetPalette.tertiary) {
                VStack(spacing: 12) {
                    driverChart
                    HStack(spacing: 0) {
                        statItem(value: "\(viewModel.driverPerformance.count)", label: "Active Drivers")
                        Divider().frame(height: 30)
                        statItem(value: "\(viewModel.totalFilteredTrips)", label: "Trips Assigned")
                        Divider().frame(height: 30)
                        statItem(value: "\(viewModel.averageDriverScore)", label: "Avg Score")
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var driverChart: some View {
        let data = viewModel.driverPerformance.prefix(5)
        if data.isEmpty {
            emptyChart("No driver trip data")
        } else {
            Chart(data, id: \.driver.id) { item in
                BarMark(
                    x: .value("Driver", item.user?.displayName ?? "Driver"),
                    y: .value("Trips", item.tripCount)
                )
                .foregroundStyle(FleetPalette.tertiary.gradient)
            }
            .chartXAxis { AxisMarks { AxisValueLabel() } }
            .chartYAxis { AxisMarks { AxisValueLabel() } }
            .frame(height: 140)
        }
    }

    // MARK: - Vehicle Health

    private var vehicleHealthCard: some View {
        NavigationLink {
            VehicleHealthDetailView(
                reportsViewModel: viewModel,
                vehiclesViewModel: vehiclesViewModel,
                maintenanceViewModel: maintenanceViewModel
            )
        } label: {
            ReportCategoryCard(title: "Vehicle Health", systemImage: "heart.fill", tint: FleetPalette.danger) {
                VStack(spacing: 12) {
                    healthChart
                    HStack(spacing: 0) {
                        let avg = viewModel.vehicleHealthScores.map(\.score).reduce(0, +) / max(viewModel.vehicleHealthScores.count, 1)
                        statItem(value: "\(avg)", label: "Avg Score")
                        Divider().frame(height: 30)
                        let critical = viewModel.vehicleHealthScores.filter { $0.score < 50 }.count
                        statItem(value: "\(critical)", label: "Needs Attention")
                        Divider().frame(height: 30)
                        statItem(value: "\(viewModel.vehicleHealthScores.count)", label: "Total Vehicles")
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var healthChart: some View {
        let data = viewModel.vehicleHealthScores.prefix(8)
        if data.isEmpty {
            emptyChart("No vehicle data")
        } else {
            Chart(data, id: \.vehicle.id) { item in
                BarMark(
                    x: .value("Vehicle", item.vehicle.licencePlate),
                    y: .value("Score", item.score)
                )
                .foregroundStyle(by: .value("Score", scoreBand(item.score)))
            }
            .chartForegroundStyleScale([
                "Good": FleetPalette.success,
                "Fair": FleetPalette.warning,
                "Poor": FleetPalette.danger
            ])
            .chartXAxis { AxisMarks { AxisValueLabel() } }
            .chartYAxis { AxisMarks { AxisValueLabel() } }
            .frame(height: 140)
        }
    }

    private func scoreBand(_ score: Int) -> String {
        score >= 70 ? "Good" : score >= 40 ? "Fair" : "Poor"
    }

    // MARK: - Helpers

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(FleetPalette.textPrimary)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(FleetPalette.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func emptyChart(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(FleetPalette.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 100)
    }
}

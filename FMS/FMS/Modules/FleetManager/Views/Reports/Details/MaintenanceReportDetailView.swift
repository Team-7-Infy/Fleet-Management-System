import SwiftUI
import Charts

struct MaintenanceReportDetailView: View {
    @ObservedObject var reportsViewModel: ReportsViewModel
    @ObservedObject var maintenanceViewModel: MaintenanceViewModel
    @ObservedObject var usersViewModel: UserManagementViewModel

    @State private var localPeriod: PeriodPreset = .oneMonth

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeader(title: "Maintenance Report", subtitle: "Work orders, costs, and parts")
                PeriodFilterPicker(selectedPeriod: $localPeriod)
                    .padding(.horizontal, 4)
                    .onChange(of: localPeriod) { _, new in
                        reportsViewModel.selectedPeriod = new
                    }

                costSummaryGrid
                costBreakdownChart
                longestWorkOrdersSection
                mostExpensiveSection
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .fleetScreenBackground()
        .navigationTitle("Maintenance")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { localPeriod = reportsViewModel.selectedPeriod }
    }

    private var costSummaryGrid: some View {
        LazyVGrid(columns: FleetPalette.twoColumnGrid, spacing: 12) {
            DashboardMetricCard(title: "Total Cost", systemImage: "indianrupeesign", tint: FleetPalette.warning, metrics: [("Amount", reportsViewModel.maintenanceCostTotal.formatted(.currency(code: "INR")))])

            let parts = reportsViewModel.maintenancePartsTotal
            DashboardMetricCard(title: "Parts Cost", systemImage: "wrench.fill", tint: FleetPalette.tertiary, metrics: [("Amount", parts.formatted(.currency(code: "INR")))])

            DashboardMetricCard(title: "Labour Cost", systemImage: "person.fill", tint: FleetPalette.accent, metrics: [("Amount", reportsViewModel.maintenanceLabourTotal.formatted(.currency(code: "INR")))])

            DashboardMetricCard(title: "Completed", systemImage: "checkmark.circle", tint: FleetPalette.success, metrics: [("Count", "\(reportsViewModel.filteredCompletedTasks.count)")])
        }
    }

    private var costBreakdownChart: some View {
        GlassPanel(hasBorder: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text("COST BREAKDOWN")
                    .font(.caption).bold()
                    .foregroundStyle(FleetPalette.textSecondary)

                let data = reportsViewModel.mostExpensiveWorkOrders.prefix(8)
                if data.isEmpty {
                    Text("No cost data available")
                        .font(.subheadline).foregroundStyle(FleetPalette.textSecondary)
                        .frame(maxWidth: .infinity).frame(height: 120)
                } else {
                    Chart(data, id: \.task.id) { item in
                        BarMark(
                            x: .value("Task", item.task.displayTitle),
                            y: .value("Cost", item.cost)
                        )
                        .foregroundStyle(FleetPalette.warning.gradient)
                    }
                    .chartXAxis { AxisMarks { AxisValueLabel(orientation: .vertical) } }
                    .frame(height: 160)
                }
            }
        }
    }

    private var longestWorkOrdersSection: some View {
        GlassPanel(hasBorder: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text("LONGEST WORK ORDERS")
                    .font(.caption).bold()
                    .foregroundStyle(FleetPalette.textSecondary)

                let items = reportsViewModel.longestWorkOrders
                if items.isEmpty {
                    Text("No completed work orders")
                        .font(.subheadline).foregroundStyle(FleetPalette.textSecondary)
                } else {
                    ForEach(items, id: \.task.id) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.task.displayTitle)
                                    .font(.subheadline).bold().foregroundStyle(FleetPalette.textPrimary)
                                if let user = usersViewModel.personnelUser(for: item.task.executedBy) {
                                    Text(user.displayName)
                                        .font(.caption).foregroundStyle(FleetPalette.textSecondary)
                                }
                            }
                            Spacer()
                            Text("\(item.hours, specifier: "%.1f") hrs")
                                .font(.subheadline).bold().foregroundStyle(FleetPalette.warning)
                        }
                        Divider()
                    }
                }
            }
        }
    }

    private var mostExpensiveSection: some View {
        GlassPanel(hasBorder: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text("MOST EXPENSIVE WORK ORDERS")
                    .font(.caption).bold()
                    .foregroundStyle(FleetPalette.textSecondary)

                let items = reportsViewModel.mostExpensiveWorkOrders
                if items.isEmpty {
                    Text("No cost data")
                        .font(.subheadline).foregroundStyle(FleetPalette.textSecondary)
                } else {
                    ForEach(items, id: \.task.id) { item in
                        HStack {
                            Text(item.task.displayTitle)
                                .font(.subheadline).bold().foregroundStyle(FleetPalette.textPrimary)
                            Spacer()
                            Text(item.cost.formatted(.currency(code: "INR")))
                                .font(.subheadline).bold().foregroundStyle(FleetPalette.danger)
                        }
                        Divider()
                    }
                }
            }
        }
    }
}

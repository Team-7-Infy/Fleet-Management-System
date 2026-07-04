import SwiftUI
import Charts

struct ExpenditureDetailView: View {
    @ObservedObject var reportsViewModel: ReportsViewModel
    @ObservedObject var maintenanceViewModel: MaintenanceViewModel

    @State private var localPeriod: PeriodPreset = .oneMonth

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeader(title: "Expenditure", subtitle: "Cost breakdown across the fleet")
                PeriodFilterPicker(selectedPeriod: $localPeriod)
                    .padding(.horizontal, 4)
                    .onChange(of: localPeriod) { _, new in
                        reportsViewModel.selectedPeriod = new
                    }

                pieSection
                summaryGrid
                maintenanceSection
                fuelSection
                miscSection
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .fleetScreenBackground()
        .navigationTitle("Expenditure")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { localPeriod = reportsViewModel.selectedPeriod }
    }

    private var pieSection: some View {
        GlassPanel(hasBorder: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text("DISTRIBUTION")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(FleetPalette.textSecondary)

                let slices = reportsViewModel.expenditureSlices
                if slices.allSatisfy({ $0.amount == 0 }) {
                    Text("No expenditure data")
                        .font(.subheadline)
                        .foregroundStyle(FleetPalette.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                } else {
                    FitnessPieChart(slices: slices, height: 220)
                }
            }
        }
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: FleetPalette.twoColumnGrid, spacing: 12) {
            DashboardMetricCard(
                title: "Total",
                systemImage: "indianrupeesign",
                tint: FleetPalette.accent,
                metrics: [("Amount", reportsViewModel.totalExpenditure.formatted(.currency(code: "INR")))]
            )
            DashboardMetricCard(
                title: "Maintenance",
                systemImage: "wrench.fill",
                tint: FleetPalette.warning,
                metrics: [
                    ("Labour", reportsViewModel.maintenanceLabourTotal.formatted(.currency(code: "INR"))),
                    ("Parts", reportsViewModel.maintenancePartsTotal.formatted(.currency(code: "INR")))
                ]
            )
            DashboardMetricCard(
                title: "Fuel",
                systemImage: "fuelpump.fill",
                tint: FleetPalette.success,
                metrics: [("Amount", reportsViewModel.filteredTripFuelTotal.formatted(.currency(code: "INR")))]
            )
            DashboardMetricCard(
                title: "Miscellaneous",
                systemImage: "ellipsis",
                tint: FleetPalette.tertiary,
                metrics: [("Amount", reportsViewModel.filteredTripMiscTotal.formatted(.currency(code: "INR")))]
            )
        }
    }

    private var maintenanceSection: some View {
        GlassPanel(hasBorder: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text("MAINTENANCE COSTS")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(FleetPalette.textSecondary)

                let items = reportsViewModel.mostExpensiveWorkOrders
                if items.isEmpty {
                    Text("No maintenance costs in this period")
                        .font(.subheadline)
                        .foregroundStyle(FleetPalette.textSecondary)
                } else {
                    ForEach(items.prefix(8), id: \.task.id) { item in
                        HStack {
                            Text(item.task.displayTitle)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(FleetPalette.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            Text(item.cost.formatted(.currency(code: "INR")))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(FleetPalette.warning)
                        }
                        Divider()
                    }
                }
            }
        }
    }

    private var fuelSection: some View {
        GlassPanel(hasBorder: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text("FUEL COSTS")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(FleetPalette.textSecondary)

                let fuelItems = reportsViewModel.topTripsByFuelCost
                if fuelItems.isEmpty {
                    Text("No fuel costs in this period")
                        .font(.subheadline)
                        .foregroundStyle(FleetPalette.textSecondary)
                } else {
                    let displayItems = fuelItems.prefix(8)
                    ForEach(Array(zip(displayItems.indices, displayItems)), id: \.0) { _, item in
                        HStack {
                            Text("\(item.trip.startLocation) \u{2192} \(item.trip.endLocation)")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(FleetPalette.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            Text(item.cost.formatted(.currency(code: "INR")))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(FleetPalette.success)
                        }
                        Divider()
                    }
                }
            }
        }
    }

    private var miscSection: some View {
        GlassPanel(hasBorder: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text("MISCELLANEOUS COSTS")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(FleetPalette.textSecondary)

                let allMisc = reportsViewModel.filteredTrips
                    .filter { ($0.miscellaneousCost ?? 0) > 0 }
                    .sorted { ($0.miscellaneousCost ?? 0) > ($1.miscellaneousCost ?? 0) }

                if allMisc.isEmpty {
                    Text("No miscellaneous costs in this period")
                        .font(.subheadline)
                        .foregroundStyle(FleetPalette.textSecondary)
                } else {
                    let displayMisc = allMisc.prefix(8)
                    ForEach(Array(zip(displayMisc.indices, displayMisc)), id: \.0) { _, trip in
                        HStack {
                            Text("\(trip.startLocation) \u{2192} \(trip.endLocation)")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(FleetPalette.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            Text((trip.miscellaneousCost ?? 0).formatted(.currency(code: "INR")))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(FleetPalette.tertiary)
                        }
                        Divider()
                    }
                }
            }
        }
    }
}

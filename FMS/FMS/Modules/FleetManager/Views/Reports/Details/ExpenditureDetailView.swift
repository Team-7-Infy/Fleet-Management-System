import SwiftUI
import Charts

struct ExpenditureDetailView: View {
    @ObservedObject var reportsViewModel: ReportsViewModel
    @ObservedObject var maintenanceViewModel: MaintenanceViewModel
    @ObservedObject var tripsManager: TripManagementViewModel
    @ObservedObject var vehiclesViewModel: VehicleViewModel
    @ObservedObject var usersViewModel: UserManagementViewModel

    @State private var localPeriod: PeriodPreset = .twoMonths

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PeriodFilterPicker(selectedPeriod: $localPeriod)
                    .padding(.horizontal, 4)
                    .onChange(of: localPeriod) { _, new in
                        reportsViewModel.selectedPeriod = new
                    }

                expenditureChart
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ReportExportToolbarItem(reportType: .expenditure, viewModel: reportsViewModel)
            }
        }
        .onAppear { localPeriod = reportsViewModel.selectedPeriod }
    }

    private var summaryGrid: some View {
        let totalValue = reportsViewModel.totalExpenditure
        let maintenanceValue = reportsViewModel.maintenanceCostTotal
        let fuelValue = reportsViewModel.filteredTripFuelTotal
        let miscValue = reportsViewModel.filteredTripMiscTotal

        return GlassPanel(hasBorder: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("EXPENDITURE SUMMARY")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: FleetPalette.twoColumnGrid, alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(totalValue.formatted(.currency(code: "INR")))
                            .font(.title3).bold()
                            .foregroundStyle(FleetPalette.textPrimary)
                            .frame(minHeight: 26, alignment: .bottom)
                        Text("Total")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(maintenanceValue.formatted(.currency(code: "INR")))
                            .font(.title3).bold()
                            .foregroundStyle(FleetPalette.textPrimary)
                            .frame(minHeight: 26, alignment: .bottom)
                        Text("Maintenance")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(fuelValue.formatted(.currency(code: "INR")))
                            .font(.title3).bold()
                            .foregroundStyle(FleetPalette.textPrimary)
                        Text("Fuel")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(miscValue.formatted(.currency(code: "INR")))
                            .font(.title3).bold()
                            .foregroundStyle(FleetPalette.textPrimary)
                        Text("Miscellaneous")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(4)
        }
    }

    private var expenditureChart: some View {
        GlassPanel(hasBorder: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text("COST BREAKDOWN")
                    .font(.caption).bold()
                    .foregroundStyle(FleetPalette.textSecondary)

                let slices = reportsViewModel.expenditureSlices
                if slices.allSatisfy({ $0.amount == 0 }) {
                    ContentUnavailableView(
                        "No Expenditure",
                        systemImage: "indianrupeesign",
                        description: Text("No cost data for this period.")
                    )
                    .frame(height: 200)
                } else {
                    FitnessPieChart(slices: slices)
                }
            }
        }
    }

    private var maintenanceSection: some View {
        GlassPanel(hasBorder: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text("MAINTENANCE COSTS")
                    .font(.caption).bold()
                    .foregroundStyle(FleetPalette.textSecondary)

                let items = reportsViewModel.mostExpensiveWorkOrders
                if items.isEmpty {
                    Text("No maintenance costs in this period")
                        .font(.subheadline)
                        .foregroundStyle(FleetPalette.textSecondary)
                } else {
                    ForEach(items.prefix(8), id: \.task.id) { item in
                        NavigationLink {
                            ManagerServiceDetailView(
                                task: item.task,
                                viewModel: maintenanceViewModel,
                                vehiclesViewModel: vehiclesViewModel,
                                usersViewModel: usersViewModel
                            )
                        } label: {
                            HStack {
                                Text(item.task.displayTitle)
                                    .font(.subheadline).bold()
                                    .foregroundStyle(FleetPalette.textPrimary)
                                    .lineLimit(1)
                                Spacer()
                                Text(item.cost.formatted(.currency(code: "INR")))
                                    .font(.subheadline).bold()
                                    .foregroundStyle(FleetPalette.warning)
                            }
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
                    .font(.caption).bold()
                    .foregroundStyle(FleetPalette.textSecondary)

                let fuelItems = reportsViewModel.topTripsByFuelCost
                if fuelItems.isEmpty {
                    Text("No fuel costs in this period")
                        .font(.subheadline)
                        .foregroundStyle(FleetPalette.textSecondary)
                } else {
                    let displayItems = fuelItems.prefix(8)
                    ForEach(Array(zip(displayItems.indices, displayItems)), id: \.0) { _, item in
                        NavigationLink {
                            ManagerTripDetailView(
                                trip: item.trip,
                                viewModel: tripsManager,
                                vehiclesViewModel: vehiclesViewModel,
                                usersViewModel: usersViewModel
                            )
                        } label: {
                            HStack {
                                Text("\(item.trip.startLocation) \u{2192} \(item.trip.endLocation)")
                                    .font(.subheadline).bold()
                                    .foregroundStyle(FleetPalette.textPrimary)
                                    .lineLimit(1)
                                Spacer()
                                Text(item.cost.formatted(.currency(code: "INR")))
                                    .font(.subheadline).bold()
                                    .foregroundStyle(FleetPalette.success)
                            }
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
                    .font(.caption).bold()
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
                        NavigationLink {
                            ManagerTripDetailView(
                                trip: trip,
                                viewModel: tripsManager,
                                vehiclesViewModel: vehiclesViewModel,
                                usersViewModel: usersViewModel
                            )
                        } label: {
                            HStack {
                                Text("\(trip.startLocation) \u{2192} \(trip.endLocation)")
                                    .font(.subheadline).bold()
                                    .foregroundStyle(FleetPalette.textPrimary)
                                    .lineLimit(1)
                                Spacer()
                                Text((trip.miscellaneousCost ?? 0).formatted(.currency(code: "INR")))
                                    .font(.subheadline).bold()
                                    .foregroundStyle(FleetPalette.tertiary)
                            }
                        }
                        Divider()
                    }
                }
            }
        }
    }
}

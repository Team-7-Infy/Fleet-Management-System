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

        return FitnessCategoryCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("EXPENDITURE SUMMARY")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(FleetPalette.accent)

                LazyVGrid(columns: FleetPalette.twoColumnGrid, spacing: 14) {
                    summaryGridCell(title: "Total Cost", value: totalValue.formatted(.currency(code: "INR")), icon: "creditcard.fill", color: FleetPalette.accent)
                    summaryGridCell(title: "Maintenance", value: maintenanceValue.formatted(.currency(code: "INR")), icon: "wrench.and.screwdriver.fill", color: FleetPalette.warning)
                    summaryGridCell(title: "Fuel Cost", value: fuelValue.formatted(.currency(code: "INR")), icon: "fuelpump.fill", color: FleetPalette.success)
                    summaryGridCell(title: "Miscellaneous", value: miscValue.formatted(.currency(code: "INR")), icon: "ellipsis.circle.fill", color: .purple)
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
                    .font(.system(size: 15, weight: .bold, design: .rounded))
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

    private var expenditureChart: some View {
        FitnessCategoryCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("COST BREAKDOWN")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(FleetPalette.accent)

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
        FitnessCategoryCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("MAINTENANCE COSTS")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(FleetPalette.warning)
                    .padding(.bottom, 4)

                let items = reportsViewModel.mostExpensiveWorkOrders
                if items.isEmpty {
                    Text("No maintenance costs in this period")
                        .font(.subheadline)
                        .foregroundStyle(FleetPalette.textSecondary)
                } else {
                    VStack(spacing: 8) {
                        ForEach(items.prefix(8), id: \.task.id) { item in
                            costRow(
                                title: item.task.displayTitle,
                                subtitle: item.task.status.title,
                                amount: item.cost,
                                color: FleetPalette.warning,
                                destination: ManagerServiceDetailView(
                                    task: item.task,
                                    viewModel: maintenanceViewModel,
                                    vehiclesViewModel: vehiclesViewModel,
                                    usersViewModel: usersViewModel
                                )
                            )
                        }
                    }
                }
            }
        }
    }

    private var fuelSection: some View {
        FitnessCategoryCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("FUEL COSTS")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(FleetPalette.success)
                    .padding(.bottom, 4)

                let fuelItems = reportsViewModel.topTripsByFuelCost
                if fuelItems.isEmpty {
                    Text("No fuel costs in this period")
                        .font(.subheadline)
                        .foregroundStyle(FleetPalette.textSecondary)
                } else {
                    let displayItems = fuelItems.prefix(8)
                    VStack(spacing: 8) {
                        ForEach(Array(zip(displayItems.indices, displayItems)), id: \.0) { _, item in
                            let licencePlate = item.trip.vehicleId.flatMap { vid in
                                vehiclesViewModel.vehicles.first(where: { $0.id == vid })?.licencePlate
                            } ?? "No Vehicle"
                            costRow(
                                title: "\(item.trip.startLocation) → \(item.trip.endLocation)",
                                subtitle: licencePlate,
                                amount: item.cost,
                                color: FleetPalette.success,
                                destination: ManagerTripDetailView(
                                    trip: item.trip,
                                    viewModel: tripsManager,
                                    vehiclesViewModel: vehiclesViewModel,
                                    usersViewModel: usersViewModel
                                )
                            )
                        }
                    }
                }
            }
        }
    }

    private var miscSection: some View {
        FitnessCategoryCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("MISCELLANEOUS COSTS")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.purple)
                    .padding(.bottom, 4)

                let allMisc = reportsViewModel.filteredTrips
                    .filter { ($0.miscellaneousCost ?? 0) > 0 }
                    .sorted { ($0.miscellaneousCost ?? 0) > ($1.miscellaneousCost ?? 0) }

                if allMisc.isEmpty {
                    Text("No miscellaneous costs in this period")
                        .font(.subheadline)
                        .foregroundStyle(FleetPalette.textSecondary)
                } else {
                    let displayMisc = allMisc.prefix(8)
                    VStack(spacing: 8) {
                        ForEach(Array(zip(displayMisc.indices, displayMisc)), id: \.0) { _, trip in
                            let licencePlate = trip.vehicleId.flatMap { vid in
                                vehiclesViewModel.vehicles.first(where: { $0.id == vid })?.licencePlate
                            } ?? "No Vehicle"
                            costRow(
                                title: "\(trip.startLocation) → \(trip.endLocation)",
                                subtitle: licencePlate,
                                amount: trip.miscellaneousCost ?? 0,
                                color: .purple,
                                destination: ManagerTripDetailView(
                                    trip: trip,
                                    viewModel: tripsManager,
                                    vehiclesViewModel: vehiclesViewModel,
                                    usersViewModel: usersViewModel
                                )
                            )
                        }
                    }
                }
            }
        }
    }

    private func costRow<Destination: View>(title: String, subtitle: String, amount: Double, color: Color, destination: Destination) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(FleetPalette.textPrimary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(FleetPalette.textSecondary)
                }
                
                Spacer(minLength: 8)
                
                HStack(spacing: 4) {
                    Text(amount.formatted(.currency(code: "INR")))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
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


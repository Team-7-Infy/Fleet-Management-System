import SwiftUI

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
            VStack(alignment: .leading, spacing: 24) {
                vehicleHealthSectionSeparator
                PeriodFilterPicker(selectedPeriod: $viewModel.selectedPeriod)
                tripSection
                expenditureSection
                fleetUtilizationSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .fleetScreenBackground()
        .navigationTitle("Reports and Analytics")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Trip Report

    private var tripSection: some View {
        NavigationLink {
            TripReportDetailView(
                tripsViewModel: viewModel,
                tripsManager: viewModel.tripsViewModel,
                vehiclesViewModel: vehiclesViewModel,
                usersViewModel: usersViewModel
            )
        } label: {
            FitnessCategoryCard {
                VStack(alignment: .leading, spacing: 4) {
                    FitnessMetricHeader(
                        label: "Trips",
                        value: "\(viewModel.totalFilteredTrips)",
                        subtitle: "Trips in selected period"
                    )

                    if let change = viewModel.tripPercentChange {
                        HStack(spacing: 4) {
                            Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.caption).bold()
                            Text("\(abs(change), specifier: "%.0f")% from last month")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(change >= 0 ? FleetPalette.success : FleetPalette.danger)
                    }
                }

                let data = viewModel.filteredTripsByMonth

                if data.allSatisfy({ $0.count == 0 }) {
                    ContentUnavailableView(
                        "No Trips",
                        systemImage: "point.topleft.down.curvedto.point.bottomright.up",
                        description: Text("No trip data for this period.")
                    )
                    .frame(height: 140)
                } else {
                    FitnessMonthlyBarChart(data: data, color: FleetPalette.accent)
                }

                navigationPill(destination: TripReportDetailView(
                    tripsViewModel: viewModel,
                    tripsManager: viewModel.tripsViewModel,
                    vehiclesViewModel: vehiclesViewModel,
                    usersViewModel: usersViewModel
                ))
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Expenditure

    private var expenditureSection: some View {
        NavigationLink {
            ExpenditureDetailView(
                reportsViewModel: viewModel,
                maintenanceViewModel: maintenanceViewModel,
                tripsManager: viewModel.tripsViewModel,
                vehiclesViewModel: vehiclesViewModel,
                usersViewModel: usersViewModel
            )
        } label: {
            FitnessCategoryCard {
                FitnessMetricHeader(
                    label: "Expenditure",
                    value: viewModel.totalExpenditure.formatted(.currency(code: "INR")),
                    subtitle: "Total cost in selected period"
                )

                let slices = viewModel.expenditureSlices
                if slices.allSatisfy({ $0.amount == 0 }) {
                    ContentUnavailableView(
                        "No Expenditure",
                        systemImage: "indianrupeesign",
                        description: Text("No cost data for this period.")
                    )
                    .frame(height: 140)
                } else {
                    FitnessPieChart(slices: slices)
                }

                navigationPill(destination: ExpenditureDetailView(
                    reportsViewModel: viewModel,
                    maintenanceViewModel: maintenanceViewModel,
                    tripsManager: viewModel.tripsViewModel,
                    vehiclesViewModel: vehiclesViewModel,
                    usersViewModel: usersViewModel
                ))
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Fleet Utilization

    private var fleetUtilizationSection: some View {
        NavigationLink {
            FleetUtilizationDetailView(
                reportsViewModel: viewModel,
                vehiclesViewModel: vehiclesViewModel,
                usersViewModel: usersViewModel
            )
        } label: {
            FitnessCategoryCard {
                FitnessMetricHeader(
                    label: "Fleet Utilization",
                    value: "\(Int(viewModel.utilizationPercentCurrentMonth.rounded()))%",
                    subtitle: "\(viewModel.vehiclesUsedThisPeriod) of \(viewModel.totalVehiclesCount) vehicles used this month"
                )

                let data = viewModel.fleetUtilizationByMonth

                if data.allSatisfy({ $0.vehiclesUsed == 0 }) {
                    ContentUnavailableView(
                        "No Utilization Data",
                        systemImage: "car.2.fill",
                        description: Text("No vehicle usage data for this period.")
                    )
                    .frame(height: 140)
                } else {
                    FitnessLineChart(
                        data: data,
                        totalVehicles: viewModel.totalVehiclesCount,
                        color: FleetPalette.success
                    )
                }

                navigationPill(destination: FleetUtilizationDetailView(
                    reportsViewModel: viewModel,
                    vehiclesViewModel: vehiclesViewModel,
                    usersViewModel: usersViewModel
                ))
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Vehicle Health (static — unaffected by period filter)

    private var vehicleHealthSectionSeparator: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("FLEET STATUS")
                .font(.caption).bold()
                .foregroundStyle(.tertiary)
                .padding(.top, 8)
            vehicleHealthSection
        }
    }

    // MARK: - Vehicle Health (aggregated from driver + vehicle scores)

    private var vehicleHealthSection: some View {
        let score = viewModel.fleetHealthScore
        let color = viewModel.fleetHealthColor
        let label = viewModel.fleetHealthLabel

        let ringGradient = AngularGradient(colors: [FleetPalette.accent, FleetPalette.success, FleetPalette.accent], center: .center, startAngle: .degrees(-90), endAngle: .degrees(270))

        return FitnessCategoryCard {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(color.opacity(0.2), lineWidth: 8)
                            .frame(width: 120, height: 120)
                        Circle()
                            .trim(from: 0, to: CGFloat(score) / 100)
                            .stroke(ringGradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 120, height: 120)
                            .rotationEffect(.degrees(-90))
                        Text("\(score)")
                            .font(.system(size: 36, weight: .heavy, design: .rounded).monospacedDigit())
                            .foregroundStyle(color)
                    }

                    Text(label)
                        .font(.title2).bold()
                        .foregroundStyle(color)
                    Text("Aggregate of vehicle health and driver scores")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)

                if score <= 90 {
                    NavigationLink {
                        VehicleHealthDetailView(
                            reportsViewModel: viewModel,
                            vehiclesViewModel: vehiclesViewModel,
                            maintenanceViewModel: maintenanceViewModel
                        )
                    } label: {
                        Text("Optimize")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(LinearGradient(colors: [FleetPalette.accent, FleetPalette.success], startPoint: .leading, endPoint: .trailing), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
                }
            }
        }
    }

    // MARK: - Helpers

    private func navigationPill<Destination: View>(destination: Destination) -> some View {
        NavigationLink(destination: destination) {
            Text("View All Metrics")
                .font(.subheadline.bold())
                .foregroundStyle(FleetPalette.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(FleetPalette.tertiary.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
    }
}

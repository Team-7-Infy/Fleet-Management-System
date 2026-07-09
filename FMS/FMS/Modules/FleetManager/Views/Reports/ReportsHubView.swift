import SwiftUI

struct ReportsHubView: View {
    @Namespace private var optimizeSpace

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

                VStack(alignment: .leading, spacing: 10) {
                    Text("TIMEFRAME")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.0)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 2)
                    PeriodFilterPicker(selectedPeriod: $viewModel.selectedPeriod)
                }

                tripSection
                expenditureSection
                fleetUtilizationSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .fleetScreenBackground()
        .navigationTitle("Reports & Analytics")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await usersViewModel.recalculateAndReloadScores() }
                } label: {
                    Label("Recalculate Scores", systemImage: "arrow.triangle.2.circlepath")
                }
                .tint(FleetPalette.textPrimary)
            }
        }
    }

    // MARK: - Trip Report

    private var tripSection: some View {
        FitnessCategoryCard {
            HStack(alignment: .top, spacing: 14) {
                IconBubble(systemImage: "point.topleft.down.curvedto.point.bottomright.up", tint: FleetPalette.accent)

                FitnessMetricHeader(
                    label: "Trips",
                    value: "\(viewModel.totalFilteredTrips)",
                    subtitle: "Trips in selected period"
                )

                Spacer()

                if let change = viewModel.tripPercentChange {
                    HStack(spacing: 4) {
                        Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10, weight: .bold))
                        Text("\(abs(change), specifier: "%.0f")%")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(change >= 0 ? FleetPalette.success : FleetPalette.danger)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background((change >= 0 ? FleetPalette.success : FleetPalette.danger).opacity(0.12))
                    .clipShape(Capsule())
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
                VStack {
                    FitnessMonthlyBarChart(data: data, color: FleetPalette.accent)
                }
                .padding(.vertical, 6)
            }

            navigationPill(destination: TripReportDetailView(
                tripsViewModel: viewModel,
                tripsManager: viewModel.tripsViewModel,
                vehiclesViewModel: vehiclesViewModel,
                usersViewModel: usersViewModel
            ))
        }
    }

    // MARK: - Expenditure

    private var expenditureSection: some View {
        FitnessCategoryCard {
            HStack(alignment: .top, spacing: 14) {
                IconBubble(systemImage: "indianrupeesign.circle.fill", tint: .orange)

                FitnessMetricHeader(
                    label: "Expenditure",
                    value: viewModel.totalExpenditure.formatted(.currency(code: "INR")),
                    subtitle: "Total cost in selected period"
                )

                Spacer()
            }

            let slices = viewModel.expenditureSlices
            if slices.allSatisfy({ $0.amount == 0 }) {
                ContentUnavailableView(
                    "No Expenditure",
                    systemImage: "indianrupeesign",
                    description: Text("No cost data for this period.")
                )
                .frame(height: 140)
            } else {
                VStack {
                    FitnessPieChart(slices: slices)
                }
                .padding(.vertical, 6)
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

    // MARK: - Fleet Utilization

    private var fleetUtilizationSection: some View {
        FitnessCategoryCard {
            HStack(alignment: .top, spacing: 14) {
                IconBubble(systemImage: "car.2.fill", tint: FleetPalette.success)

                FitnessMetricHeader(
                    label: "Fleet Utilization",
                    value: "\(Int(viewModel.utilizationPercentCurrentMonth.rounded()))%",
                    subtitle: "\(viewModel.vehiclesUsedThisPeriod) of \(viewModel.totalVehiclesCount) vehicles used this month"
                )

                Spacer()
            }

            let data = viewModel.fleetUtilizationByMonth

            if data.allSatisfy({ $0.vehiclesUsed == 0 }) {
                ContentUnavailableView(
                    "No Utilization Data",
                    systemImage: "car.2.fill",
                    description: Text("No vehicle usage data for this period.")
                )
                .frame(height: 140)
            } else {
                VStack {
                    FitnessLineChart(
                        data: data,
                        totalVehicles: viewModel.totalVehiclesCount,
                        color: FleetPalette.success
                    )
                }
                .padding(.vertical, 6)
            }

            navigationPill(destination: FleetUtilizationDetailView(
                reportsViewModel: viewModel,
                vehiclesViewModel: vehiclesViewModel,
                usersViewModel: usersViewModel,
                maintenanceViewModel: maintenanceViewModel
            ))
        }
    }

    // MARK: - Vehicle Health (static — unaffected by period filter)

    private var vehicleHealthSectionSeparator: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FLEET STATUS")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.0)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
                .padding(.horizontal, 2)
            vehicleHealthSection
        }
    }

    // MARK: - Vehicle Health (aggregated from driver + vehicle scores)

    private var vehicleHealthSection: some View {
        let score = viewModel.fleetHealthScore
        let color = viewModel.fleetHealthColor
        let label = viewModel.fleetHealthLabel

        let ringGradient = AngularGradient(
            colors: [color, color.opacity(0.6), color],
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
        )

        return FitnessCategoryCard {
            VStack(spacing: 22) {
                HStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .stroke(color.opacity(0.12), lineWidth: 10)
                            .frame(width: 106, height: 106)
                        Circle()
                            .trim(from: 0, to: CGFloat(score) / 100)
                            .stroke(ringGradient, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .frame(width: 106, height: 106)
                            .rotationEffect(.degrees(-90))
                            .shadow(color: color.opacity(0.3), radius: 5, x: 0, y: 3)

                        VStack(spacing: -2) {
                            Text("\(score)")
                                .font(.system(size: 30, weight: .black, design: .rounded).monospacedDigit())
                                .foregroundStyle(color)
                            Text("score")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.secondary.opacity(0.7))
                        }
                    }
                    .padding(4)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(label.uppercased())
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundStyle(color)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(color.opacity(0.12))
                                .clipShape(Capsule())
                        }

                        Text("Fleet Health Index")
                            .font(.headline.bold())
                            .foregroundStyle(FleetPalette.textPrimary)

                        Text("Aggregate of vehicle health and driver scores")
                            .font(.caption)
                            .foregroundStyle(FleetPalette.textSecondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if score <= 90 {
                    NavigationLink {
                        FleetOptimizationView(
                            reportsViewModel: viewModel,
                            vehiclesViewModel: vehiclesViewModel,
                            usersViewModel: usersViewModel,
                            maintenanceViewModel: maintenanceViewModel
                        )
                        .navigationTransition(
                            .zoom(sourceID: "optimizeButton", in: optimizeSpace)
                        )
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.subheadline.bold())
                            Text("Optimize Performance")
                                .font(.subheadline.bold())
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [FleetPalette.accent, FleetPalette.success],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: Capsule()
                        )
                        .shadow(color: FleetPalette.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
                    .matchedTransitionSource(id: "optimizeButton", in: optimizeSpace)
                }
            }
        }
    }

    // MARK: - Helpers

    private func navigationPill<Destination: View>(destination: Destination) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 6) {
                Text("View Detailed Metrics")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(FleetPalette.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(FleetPalette.accent.opacity(0.08))
            )
            .overlay {
                Capsule()
                    .stroke(FleetPalette.accent.opacity(0.15), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
    }
}

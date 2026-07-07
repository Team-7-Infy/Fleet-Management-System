import SwiftUI
import Charts

struct TripReportDetailView: View {
    @ObservedObject var tripsViewModel: ReportsViewModel
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
                        tripsViewModel.selectedPeriod = new
                    }

                tripChart
                summaryGrid
                punctualitySection
                fuelExpenditureSection
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .fleetScreenBackground()
        .navigationTitle("Trip Report")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ReportExportToolbarItem(reportType: .trip, viewModel: tripsViewModel)
            }
        }
        .onAppear {
            localPeriod = tripsViewModel.selectedPeriod
        }
    }

    private var tripChart: some View {
        GlassPanel(hasBorder: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text("MONTHLY TRIPS")
                    .font(.caption).bold()
                    .foregroundStyle(FleetPalette.textSecondary)

                let data = tripsViewModel.filteredTripsByMonth

                if data.allSatisfy({ $0.count == 0 }) {
                    ContentUnavailableView(
                        "No Trips",
                        systemImage: "point.topleft.down.curvedto.point.bottomright.up",
                        description: Text("No trip data for this period.")
                    )
                    .frame(height: 180)
                } else {
                    FitnessMonthlyBarChart(data: data, color: FleetPalette.accent)
                }
            }
        }
    }

    private var summaryGrid: some View {
        let completed = tripsViewModel.totalFilteredCompletedTrips
        let total = tripsViewModel.totalFilteredTrips
        let totalCost = tripsViewModel.filteredTripCostTotal
        let avgCost = completed > 0 ? totalCost / Double(completed) : 0

        return GlassPanel(hasBorder: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("TRIP SUMMARY")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: FleetPalette.twoColumnGrid, alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(total)")
                            .font(.title3).bold()
                            .foregroundStyle(FleetPalette.textPrimary)
                            .frame(minHeight: 26, alignment: .bottom)
                        Text("Total Trips")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(completed)")
                            .font(.title3).bold()
                            .foregroundStyle(FleetPalette.textPrimary)
                            .frame(minHeight: 26, alignment: .bottom)
                        Text("Completed")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(totalCost.formatted(.currency(code: "INR")))
                            .font(.title3).bold()
                            .foregroundStyle(FleetPalette.textPrimary)
                        Text("Total Cost")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(avgCost.formatted(.currency(code: "INR")))
                            .font(.title3).bold()
                            .foregroundStyle(FleetPalette.textPrimary)
                        Text("Avg / Trip")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(4)
        }
    }

    private var punctualitySection: some View {
        let onTime = Array(tripsViewModel.onTimeTrips.prefix(5))
        let delayed = Array(tripsViewModel.delayedTrips.prefix(5))
        let onTimeCount = onTime.count
        let delayedCount = delayed.count
        let total = onTimeCount + delayedCount
        let punctualityRate = total > 0 ? Double(onTimeCount) / Double(total) * 100 : 0

        return GlassPanel(hasBorder: false) {
            VStack(alignment: .leading, spacing: 16) {
                Label("Trip Punctuality", systemImage: "clock.badge.checkmark")
                    .font(.headline)
                    .foregroundStyle(FleetPalette.textPrimary)

                if total == 0 {
                    ContentUnavailableView(
                        "No completed trips to evaluate",
                        systemImage: "clock.badge.questionmark",
                        description: Text("Complete trips to see punctuality data.")
                    )
                    .frame(height: 120)
                } else {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(onTimeCount) of \(total)")
                                .font(.title3).bold()
                            Text("on time")
                                .font(.caption).foregroundStyle(.tertiary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(Int(punctualityRate.rounded()))%")
                                .font(.title3).bold()
                                .foregroundStyle(punctualityRate >= 70 ? FleetPalette.success : FleetPalette.warning)
                            Text("punctuality")
                                .font(.caption).foregroundStyle(.tertiary)
                        }
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.quaternary).frame(height: 8)
                            Capsule()
                                .fill(punctualityRate >= 70 ? FleetPalette.success.gradient : FleetPalette.warning.gradient)
                                .frame(width: geo.size.width * CGFloat(punctualityRate / 100), height: 8)
                        }
                    }
                    .frame(height: 8)

                    if onTime.isEmpty == false {
                        Text("Most On-Time")
                            .font(.subheadline).bold()
                            .foregroundStyle(FleetPalette.success)
                        ForEach(onTime, id: \.trip.id) { item in
                            NavigationLink {
                                ManagerTripDetailView(
                                    trip: item.trip,
                                    viewModel: tripsManager,
                                    vehiclesViewModel: vehiclesViewModel,
                                    usersViewModel: usersViewModel
                                )
                            } label: {
                                HStack(spacing: 8) {
                                    Circle().fill(FleetPalette.success).frame(width: 6, height: 6)
                                    Text("\(item.trip.startLocation) → \(item.trip.endLocation)")
                                        .font(.subheadline)
                                        .foregroundStyle(FleetPalette.textPrimary)
                                        .lineLimit(1)
                                    Spacer()
                                    Text("\(Int(abs(item.deviation) / 60)) min early")
                                        .font(.subheadline).bold()
                                        .foregroundStyle(FleetPalette.success)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if delayed.isEmpty == false {
                        if onTime.isEmpty == false { Divider() }
                        Text("Most Delayed")
                            .font(.subheadline).bold()
                            .foregroundStyle(FleetPalette.danger)
                        ForEach(delayed, id: \.trip.id) { item in
                            NavigationLink {
                                ManagerTripDetailView(
                                    trip: item.trip,
                                    viewModel: tripsManager,
                                    vehiclesViewModel: vehiclesViewModel,
                                    usersViewModel: usersViewModel
                                )
                            } label: {
                                HStack(spacing: 8) {
                                    Circle().fill(FleetPalette.danger).frame(width: 6, height: 6)
                                    Text("\(item.trip.startLocation) → \(item.trip.endLocation)")
                                        .font(.subheadline)
                                        .foregroundStyle(FleetPalette.textPrimary)
                                        .lineLimit(1)
                                    Spacer()
                                    Text("\(Int(item.deviation / 60)) min late")
                                        .font(.subheadline).bold()
                                        .foregroundStyle(FleetPalette.danger)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var fuelExpenditureSection: some View {
        let top = Array(tripsViewModel.topTripsByFuelCost.prefix(5))
        let bottom = Array(tripsViewModel.bottomTripsByFuelCost.prefix(5))
        let totalFuel = tripsViewModel.filteredTripFuelTotal
        let completedCount = tripsViewModel.filteredCompletedTrips.count
        let avgFuel = completedCount > 0 ? totalFuel / Double(completedCount) : 0

        return GlassPanel(hasBorder: false) {
            VStack(alignment: .leading, spacing: 16) {
                Label("Fuel Expenditure", systemImage: "fuelpump.fill")
                    .font(.headline)
                    .foregroundStyle(FleetPalette.textPrimary)

                if top.isEmpty {
                    ContentUnavailableView(
                        "No fuel data recorded",
                        systemImage: "fuelpump",
                        description: Text("Add fuel costs to trips to see data.")
                    )
                    .frame(height: 120)
                } else {
                    HStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(totalFuel.formatted(.currency(code: "INR")))
                                .font(.title3).bold()
                            Text("Total fuel")
                                .font(.caption).foregroundStyle(.tertiary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(avgFuel.formatted(.currency(code: "INR")))
                                .font(.title3).bold()
                            Text("Avg / trip")
                                .font(.caption).foregroundStyle(.tertiary)
                        }
                    }

                    Divider()

                    Text("Highest Fuel Cost")
                        .font(.subheadline).bold()
                        .foregroundStyle(FleetPalette.warning)
                    ForEach(top, id: \.trip.id) { item in
                        NavigationLink {
                            ManagerTripDetailView(
                                trip: item.trip,
                                viewModel: tripsManager,
                                vehiclesViewModel: vehiclesViewModel,
                                usersViewModel: usersViewModel
                            )
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.up.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(FleetPalette.warning)
                                Text("\(item.trip.startLocation) → \(item.trip.endLocation)")
                                    .font(.subheadline)
                                    .foregroundStyle(FleetPalette.textPrimary)
                                    .lineLimit(1)
                                Spacer()
                                Text(item.cost.formatted(.currency(code: "INR")))
                                    .font(.subheadline).bold()
                                    .foregroundStyle(FleetPalette.warning)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    Divider()

                    Text("Lowest Fuel Cost")
                        .font(.subheadline).bold()
                        .foregroundStyle(FleetPalette.success)
                    ForEach(bottom, id: \.trip.id) { item in
                        NavigationLink {
                            ManagerTripDetailView(
                                trip: item.trip,
                                viewModel: tripsManager,
                                vehiclesViewModel: vehiclesViewModel,
                                usersViewModel: usersViewModel
                            )
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.down.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(FleetPalette.success)
                                Text("\(item.trip.startLocation) → \(item.trip.endLocation)")
                                    .font(.subheadline)
                                    .foregroundStyle(FleetPalette.textPrimary)
                                    .lineLimit(1)
                                Spacer()
                                Text(item.cost.formatted(.currency(code: "INR")))
                                    .font(.subheadline).bold()
                                    .foregroundStyle(FleetPalette.success)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

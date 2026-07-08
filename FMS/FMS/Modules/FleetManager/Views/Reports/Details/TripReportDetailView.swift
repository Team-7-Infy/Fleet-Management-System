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
        FitnessCategoryCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("MONTHLY TRIPS")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(FleetPalette.accent)

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

        return FitnessCategoryCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("TRIP SUMMARY")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(FleetPalette.accent)

                LazyVGrid(columns: FleetPalette.twoColumnGrid, spacing: 14) {
                    summaryGridCell(title: "Total Trips", value: "\(total)", icon: "play.circle.fill", color: FleetPalette.accent)
                    summaryGridCell(title: "Completed", value: "\(completed)", icon: "checkmark.circle.fill", color: FleetPalette.success)
                    summaryGridCell(title: "Total Cost", value: totalCost.formatted(.currency(code: "INR")), icon: "indianrupeesign.circle.fill", color: .orange)
                    summaryGridCell(title: "Avg / Trip", value: avgCost.formatted(.currency(code: "INR")), icon: "chart.bar.doc.horizontal.fill", color: .purple)
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

    private var punctualitySection: some View {
        let onTime = Array(tripsViewModel.onTimeTrips.prefix(5))
        let delayed = Array(tripsViewModel.delayedTrips.prefix(5))
        let onTimeCount = onTime.count
        let delayedCount = delayed.count
        let total = onTimeCount + delayedCount
        let punctualityRate = total > 0 ? Double(onTimeCount) / Double(total) * 100 : 0

        return FitnessCategoryCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "clock.badge.checkmark.fill")
                        .font(.title3)
                        .foregroundStyle(FleetPalette.accent)
                    Text("Trip Punctuality")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(FleetPalette.textPrimary)
                }

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
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                            Text("on time")
                                .font(.footnote).foregroundStyle(FleetPalette.textSecondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(Int(punctualityRate.rounded()))%")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(punctualityRate >= 70 ? FleetPalette.success : FleetPalette.warning)
                            Text("punctuality")
                                .font(.footnote).foregroundStyle(FleetPalette.textSecondary)
                        }
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(FleetPalette.background).frame(height: 10)
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [
                                        punctualityRate >= 70 ? FleetPalette.success : FleetPalette.warning,
                                        (punctualityRate >= 70 ? FleetPalette.success : FleetPalette.warning).opacity(0.7)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                                .frame(width: geo.size.width * CGFloat(punctualityRate / 100), height: 10)
                                .shadow(color: (punctualityRate >= 70 ? FleetPalette.success : FleetPalette.warning).opacity(0.2), radius: 3, x: 0, y: 1)
                        }
                    }
                    .frame(height: 10)
                    .overlay {
                        Capsule().stroke(FleetPalette.tertiary.opacity(0.12), lineWidth: 1)
                    }

                    if onTime.isEmpty == false {
                        Text("Most On-Time")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(0.8)
                            .foregroundStyle(FleetPalette.success)
                            .padding(.top, 8)
                        
                        VStack(spacing: 8) {
                            ForEach(onTime, id: \.trip.id) { item in
                                NavigationLink {
                                    ManagerTripDetailView(
                                        trip: item.trip,
                                        viewModel: tripsManager,
                                        vehiclesViewModel: vehiclesViewModel,
                                        usersViewModel: usersViewModel
                                    )
                                } label: {
                                    punctualityRow(item: item, isEarly: true)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if delayed.isEmpty == false {
                        Text("Most Delayed")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(0.8)
                            .foregroundStyle(FleetPalette.danger)
                            .padding(.top, 8)
                        
                        VStack(spacing: 8) {
                            ForEach(delayed, id: \.trip.id) { item in
                                NavigationLink {
                                    ManagerTripDetailView(
                                        trip: item.trip,
                                        viewModel: tripsManager,
                                        vehiclesViewModel: vehiclesViewModel,
                                        usersViewModel: usersViewModel
                                    )
                                } label: {
                                    punctualityRow(item: item, isEarly: false)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    private func punctualityRow(item: (trip: Trip, deviation: TimeInterval), isEarly: Bool) -> some View {
        let licencePlate = item.trip.vehicleId.flatMap { vid in
            vehiclesViewModel.vehicles.first(where: { $0.id == vid })?.licencePlate
        } ?? "No Vehicle"

        return HStack(spacing: 12) {
            Image(systemName: isEarly ? "arrow.down.right.circle.fill" : "arrow.up.right.circle.fill")
                .font(.title3)
                .foregroundStyle(isEarly ? FleetPalette.success : FleetPalette.danger)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(item.trip.startLocation) → \(item.trip.endLocation)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FleetPalette.textPrimary)
                    .lineLimit(1)
                
                Text(licencePlate)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(FleetPalette.textSecondary)
            }
            
            Spacer(minLength: 8)
            
            HStack(spacing: 4) {
                Text(isEarly ? "\(Int(abs(item.deviation) / 60))m early" : "\(Int(item.deviation / 60))m late")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(isEarly ? FleetPalette.success : FleetPalette.danger)
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

    private var fuelExpenditureSection: some View {
        let top = Array(tripsViewModel.topTripsByFuelCost.prefix(5))
        let bottom = Array(tripsViewModel.bottomTripsByFuelCost.prefix(5))
        let totalFuel = tripsViewModel.filteredTripFuelTotal
        let completedCount = tripsViewModel.filteredCompletedTrips.count
        let avgFuel = completedCount > 0 ? totalFuel / Double(completedCount) : 0

        return FitnessCategoryCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "fuelpump.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)
                    Text("Fuel Expenditure")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(FleetPalette.textPrimary)
                }

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
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(FleetPalette.textPrimary)
                            Text("Total fuel")
                                .font(.footnote).foregroundStyle(FleetPalette.textSecondary)
                        }
                        
                        Divider()
                            .frame(height: 36)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(avgFuel.formatted(.currency(code: "INR")))
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(FleetPalette.textPrimary)
                            Text("Avg / trip")
                                .font(.footnote).foregroundStyle(FleetPalette.textSecondary)
                        }
                    }
                    .padding(.vertical, 4)

                    Text("Highest Fuel Cost")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(FleetPalette.warning)
                        .padding(.top, 8)
                    
                    VStack(spacing: 8) {
                        ForEach(top, id: \.trip.id) { item in
                            NavigationLink {
                                ManagerTripDetailView(
                                    trip: item.trip,
                                    viewModel: tripsManager,
                                    vehiclesViewModel: vehiclesViewModel,
                                    usersViewModel: usersViewModel
                                )
                            } label: {
                                fuelRow(item: item, isHighest: true)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("Lowest Fuel Cost")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(FleetPalette.success)
                        .padding(.top, 8)
                    
                    VStack(spacing: 8) {
                        ForEach(bottom, id: \.trip.id) { item in
                            NavigationLink {
                                ManagerTripDetailView(
                                    trip: item.trip,
                                    viewModel: tripsManager,
                                    vehiclesViewModel: vehiclesViewModel,
                                    usersViewModel: usersViewModel
                                )
                            } label: {
                                fuelRow(item: item, isHighest: false)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func fuelRow(item: (trip: Trip, cost: Double), isHighest: Bool) -> some View {
        let licencePlate = item.trip.vehicleId.flatMap { vid in
            vehiclesViewModel.vehicles.first(where: { $0.id == vid })?.licencePlate
        } ?? "No Vehicle"

        return HStack(spacing: 12) {
            Image(systemName: isHighest ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                .font(.title3)
                .foregroundStyle(isHighest ? FleetPalette.warning : FleetPalette.success)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(item.trip.startLocation) → \(item.trip.endLocation)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FleetPalette.textPrimary)
                    .lineLimit(1)
                
                Text(licencePlate)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(FleetPalette.textSecondary)
            }
            
            Spacer(minLength: 8)
            
            HStack(spacing: 4) {
                Text(item.cost.formatted(.currency(code: "INR")))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(isHighest ? FleetPalette.warning : FleetPalette.success)
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
}


import Foundation
import Combine

enum PeriodPreset: String, CaseIterable, Identifiable, Sendable {
    case oneMonth = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case oneYear = "1Y"

    var id: String { rawValue }

    var calendarMonths: Int {
        switch self {
        case .oneMonth: return 1
        case .threeMonths: return 3
        case .sixMonths: return 6
        case .oneYear: return 12
        }
    }

    var dateRange: Range<Date> {
        let now = Date()
        let start = Calendar.current.date(byAdding: .month, value: -calendarMonths, to: now) ?? now
        return start..<now
    }
}

@MainActor
final class ReportsViewModel: ObservableObject {
    @Published var selectedPeriod: PeriodPreset = .oneMonth

    private let tripsViewModel: TripManagementViewModel
    private let vehiclesViewModel: VehicleViewModel
    private let maintenanceViewModel: MaintenanceViewModel
    private let usersViewModel: UserManagementViewModel

    init(
        tripsViewModel: TripManagementViewModel,
        vehiclesViewModel: VehicleViewModel,
        maintenanceViewModel: MaintenanceViewModel,
        usersViewModel: UserManagementViewModel
    ) {
        self.tripsViewModel = tripsViewModel
        self.vehiclesViewModel = vehiclesViewModel
        self.maintenanceViewModel = maintenanceViewModel
        self.usersViewModel = usersViewModel
    }

    // MARK: - Period Helpers

    private var currentMonthRange: Range<Date> {
        PeriodPreset.oneMonth.dateRange
    }

    var periodRange: Range<Date> {
        selectedPeriod.dateRange
    }

    private func trips(in range: Range<Date>) -> [Trip] {
        tripsViewModel.trips.filter { $0.startTime >= range.lowerBound && $0.startTime < range.upperBound }
    }

    private func tasks(in range: Range<Date>) -> [MaintenanceTask] {
        maintenanceViewModel.tasks.filter {
            let date = $0.completedAt ?? $0.reportedOrScheduledDate
            return date >= range.lowerBound && date < range.upperBound
        }
    }

    // MARK: - Dashboard Summary KPIs

    var tripsThisMonthCount: Int {
        trips(in: currentMonthRange).count
    }

    var completedTripsThisMonthCount: Int {
        trips(in: currentMonthRange).filter { $0.status == .completed }.count
    }

    var completionRate: Double {
        let total = tripsThisMonthCount
        guard total > 0 else { return 0 }
        return Double(completedTripsThisMonthCount) / Double(total)
    }

    var tripCountChangePercent: Double {
        let now = Date()
        let twoMonthsAgo = Calendar.current.date(byAdding: .month, value: -2, to: now) ?? now
        let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: now) ?? now
        let lastMonthCount = tripsViewModel.trips.filter { $0.startTime >= twoMonthsAgo && $0.startTime < oneMonthAgo }.count
        guard lastMonthCount > 0 else { return 0 }
        return (Double(tripsThisMonthCount) - Double(lastMonthCount)) / Double(lastMonthCount) * 100
    }

    var fleetHealthScore: Int {
        let vehicles = vehiclesViewModel.vehicles
        guard vehicles.isEmpty == false else { return 0 }
        let activeRatio = Double(vehicles.filter { $0.status == .active }.count) / Double(vehicles.count)
        let overdueCount = maintenanceViewModel.tasks.filter { $0.status != .completed }.count
        let overduePenalty = min(Double(overdueCount) * 5, 30)
        let score = (activeRatio * 80) - overduePenalty + 20
        return max(0, min(100, Int(score.rounded())))
    }

    var overdueMaintenanceCount: Int {
        maintenanceViewModel.tasks.filter { $0.status != .completed }.count
    }

    var vehiclesInMaintenanceCount: Int {
        vehiclesViewModel.maintenanceVehicles.count
    }

    var openTasksCount: Int {
        maintenanceViewModel.openTasks.count
    }

    var urgentTasksCount: Int {
        maintenanceViewModel.tasks.filter { $0.isUrgent && $0.status != .completed }.count
    }

    var currentMonthMaintenanceCost: Double {
        tasks(in: currentMonthRange).reduce(0) { $0 + ($1.totalCost ?? 0) }
    }

    var currentMonthTripFuelCost: Double {
        trips(in: currentMonthRange).reduce(0) { $0 + ($1.fuelCost ?? 0) }
    }

    var currentMonthTripMiscCost: Double {
        trips(in: currentMonthRange).reduce(0) { $0 + ($1.miscellaneousCost ?? 0) }
    }

    var currentMonthTotalExpenditure: Double {
        currentMonthMaintenanceCost + currentMonthTripFuelCost + currentMonthTripMiscCost
    }

    // MARK: - Period-filtered Hub Data

    var filteredTrips: [Trip] {
        trips(in: periodRange)
    }

    var filteredCompletedTrips: [Trip] {
        filteredTrips.filter { $0.status == .completed }
    }

    var totalFilteredTrips: Int { filteredTrips.count }
    var totalFilteredCompletedTrips: Int { filteredCompletedTrips.count }

    var filteredTripCostTotal: Double {
        filteredTrips.reduce(0) { $0 + $1.totalCost }
    }

    var filteredTripsByWeek: [(weekStart: Date, count: Int)] {
        let calendar = Calendar.current
        var weekCounts: [Date: Int] = [:]
        for trip in filteredTrips {
            let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: trip.startTime)
            guard let weekStart = calendar.date(from: comps) else { continue }
            weekCounts[weekStart, default: 0] += 1
        }
        return weekCounts.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    var filteredCompletedTasks: [MaintenanceTask] {
        tasks(in: periodRange).filter { $0.status == .completed }
    }

    var maintenanceCostTotal: Double {
        filteredCompletedTasks.reduce(0) { $0 + ($1.totalCost ?? 0) }
    }

    var maintenanceLabourTotal: Double {
        filteredCompletedTasks.reduce(0) { $0 + ($1.labourCost ?? 0) }
    }

    var maintenancePartsTotal: Double {
        maintenanceCostTotal - maintenanceLabourTotal
    }

    var longestWorkOrders: [(task: MaintenanceTask, hours: Double)] {
        var result: [(MaintenanceTask, Double)] = []
        for t in filteredCompletedTasks {
            if let h = t.timeTakenHours, h > 0 {
                result.append((t, h))
            }
        }
        result.sort { $0.1 > $1.1 }
        return Array(result.prefix(10)).map { ($0.0, $0.1) }
    }

    var mostExpensiveWorkOrders: [(task: MaintenanceTask, cost: Double)] {
        var result: [(MaintenanceTask, Double)] = []
        for t in filteredCompletedTasks {
            if let c = t.totalCost, c > 0 {
                result.append((t, c))
            }
        }
        result.sort { $0.1 > $1.1 }
        return Array(result.prefix(10)).map { ($0.0, $0.1) }
    }

    var topTripsByFuelCost: [(trip: Trip, cost: Double)] {
        var result: [(Trip, Double)] = []
        for t in filteredCompletedTrips {
            if let c = t.fuelCost, c > 0 {
                result.append((t, c))
            }
        }
        result.sort { $0.1 > $1.1 }
        return Array(result.prefix(10)).map { ($0.0, $0.1) }
    }

    var bottomTripsByFuelCost: [(trip: Trip, cost: Double)] {
        var result: [(Trip, Double)] = []
        for t in filteredCompletedTrips {
            if let c = t.fuelCost, c > 0 {
                result.append((t, c))
            }
        }
        result.sort { $0.1 < $1.1 }
        return Array(result.prefix(10)).map { ($0.0, $0.1) }
    }

    typealias PunctualityItem = (trip: Trip, deviation: TimeInterval)

    var onTimeTrips: [PunctualityItem] {
        let completed = filteredCompletedTrips.filter { $0.endTime != nil }
        let withDiff: [PunctualityItem] = completed.compactMap { t in
            guard let end = t.endTime else { return nil }
            let expectedDuration: TimeInterval = 8 * 3600
            return (t, end.timeIntervalSince(t.startTime.addingTimeInterval(expectedDuration)))
        }
        return withDiff.filter { $0.deviation <= 0 }.sorted { $0.deviation > $1.deviation }.prefix(10).map { $0 }
    }

    var delayedTrips: [PunctualityItem] {
        let completed = filteredCompletedTrips.filter { $0.endTime != nil }
        let withDiff: [PunctualityItem] = completed.compactMap { t in
            guard let end = t.endTime else { return nil }
            let expectedDuration: TimeInterval = 8 * 3600
            return (t, end.timeIntervalSince(t.startTime.addingTimeInterval(expectedDuration)))
        }
        return withDiff.filter { $0.deviation > 0 }.sorted { $0.deviation > $1.deviation }.prefix(10).map { $0 }
    }

    var vehicleUtilization: [(vehicle: Vehicle, tripCount: Int)] {
        vehiclesViewModel.vehicles
            .map { v in (v, filteredTrips.filter { $0.vehicleId == v.id }.count) }
            .filter { $0.tripCount > 0 }
            .sorted { $0.tripCount > $1.tripCount }
    }

    var driverPerformance: [(driver: Driver, user: User?, tripCount: Int)] {
        usersViewModel.drivers
            .map { d in (d, usersViewModel.user(for: d.userId), filteredTrips.filter { $0.driverId == d.id }.count) }
            .filter { $0.tripCount > 0 }
            .sorted { $0.tripCount > $1.tripCount }
    }

    var averageDriverScore: Int {
        let scores = usersViewModel.drivers.map { _ in
            75
        }
        guard scores.isEmpty == false else { return 0 }
        return scores.reduce(0, +) / scores.count
    }

    var vehicleHealthScores: [(vehicle: Vehicle, score: Int)] {
        vehiclesViewModel.vehicles.map { v in
            let age = v.addedToFleetAt ?? Date()
            let years = Calendar.current.dateComponents([.year], from: age, to: Date()).year ?? 0
            let ageScore = max(0, 100 - years * 10)

            let vehicleTaskCount = maintenanceViewModel.tasks.filter { t in
                maintenanceViewModel.vehicles(for: t).contains { $0.vin == v.id }
            }.count
            let maintenanceScore = max(0, 100 - vehicleTaskCount * 8)
            let defectScore = vehicleTaskCount > 3 ? max(0, 70 - (vehicleTaskCount - 3) * 10) : 100

            let overall = (ageScore + maintenanceScore + defectScore) / 3
            return (v, max(0, min(100, overall)))
        }.sorted { $0.score > $1.score }
    }
}

func shortDateStr(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "d MMM"
    return f.string(from: date)
}

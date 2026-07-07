import UIKit
import Foundation

enum ReportType: String, CaseIterable {
    case trip = "Trip Report"
    case expenditure = "Expenditure Report"
    case fleetUtilization = "Fleet Utilization"
    case driverPerformance = "Driver Performance"
    case vehicleHealth = "Vehicle Health"
    case maintenance = "Maintenance Report"

    var filename: String {
        switch self {
        case .trip: "trip_report"
        case .expenditure: "expenditure_report"
        case .fleetUtilization: "fleet_utilization"
        case .driverPerformance: "driver_performance"
        case .vehicleHealth: "vehicle_health"
        case .maintenance: "maintenance_report"
        }
    }
}

struct ReportExporter {

    // MARK: - CSV

    static func csvString(for reportType: ReportType, viewModel: ReportsViewModel) -> String {
        var lines: [String] = []
        lines.append(reportType.rawValue)
        lines.append("Period: \(viewModel.selectedPeriod.rawValue)")
        lines.append("")
        switch reportType {
        case .trip: csvTripReport(&lines, viewModel)
        case .expenditure: csvExpenditure(&lines, viewModel)
        case .fleetUtilization: csvFleetUtilization(&lines, viewModel)
        case .driverPerformance: csvDriverPerformance(&lines, viewModel)
        case .vehicleHealth: csvVehicleHealth(&lines, viewModel)
        case .maintenance: csvMaintenance(&lines, viewModel)
        }
        return lines.joined(separator: "\n")
    }

    private static func csvTripReport(_ lines: inout [String], _ vm: ReportsViewModel) {
        lines.append("Summary")
        lines.append("Total Trips,Completed,Total Cost,Avg Cost")
        let total = vm.totalFilteredTrips
        let completed = vm.totalFilteredCompletedTrips
        let totalCost = vm.filteredTripCostTotal
        let avgCost = completed > 0 ? totalCost / Double(completed) : 0
        lines.append("\(total),\(completed),\(totalCost.formatted(.currency(code: "INR"))),\(avgCost.formatted(.currency(code: "INR")))")
        lines.append("")
        lines.append("Trip Details")
        lines.append("Date,Start,End,Status,Fuel Cost,Misc Cost,Total Cost")
        for t in vm.filteredTrips {
            let date = shortDateStr(t.startTime)
            let status = t.status.title
            let fuel = (t.fuelCost ?? 0).formatted(.currency(code: "INR"))
            let misc = (t.miscellaneousCost ?? 0).formatted(.currency(code: "INR"))
            lines.append("\(date),\(csvEscaped(t.startLocation)),\(csvEscaped(t.endLocation)),\(status),\(fuel),\(misc),\(t.totalCost.formatted(.currency(code: "INR")))")
        }
        lines.append("")
        lines.append("Punctuality")
        lines.append("On-Time Trips,Delayed Trips,Punctuality Rate")
        let onTime = vm.onTimeTrips.count
        let delayed = vm.delayedTrips.count
        let punctualityRate = (onTime + delayed) > 0 ? Double(onTime) / Double(onTime + delayed) * 100 : 0
        lines.append("\(onTime),\(delayed),\(Int(punctualityRate.rounded()))%")
    }

    private static func csvExpenditure(_ lines: inout [String], _ vm: ReportsViewModel) {
        lines.append("Summary")
        lines.append("Category,Amount")
        lines.append("Total,\(vm.totalExpenditure.formatted(.currency(code: "INR")))")
        lines.append("Maintenance,\(vm.maintenanceCostTotal.formatted(.currency(code: "INR")))")
        lines.append("Fuel,\(vm.filteredTripFuelTotal.formatted(.currency(code: "INR")))")
        lines.append("Misc,\(vm.filteredTripMiscTotal.formatted(.currency(code: "INR")))")
        lines.append("")
        lines.append("Top Maintenance Work Orders")
        lines.append("Task,Cost")
        for item in vm.mostExpensiveWorkOrders {
            lines.append("\(csvEscaped(item.task.displayTitle)),\(item.cost.formatted(.currency(code: "INR")))")
        }
        lines.append("")
        lines.append("Top Fuel Costs by Trip")
        lines.append("Trip,Cost")
        for item in vm.topTripsByFuelCost {
            lines.append("\(csvEscaped(item.trip.startLocation)) -> \(csvEscaped(item.trip.endLocation)),\(item.cost.formatted(.currency(code: "INR")))")
        }
    }

    private static func csvFleetUtilization(_ lines: inout [String], _ vm: ReportsViewModel) {
        lines.append("Summary")
        lines.append("Metric,Value")
        lines.append("Total Vehicles,\(vm.totalVehiclesCount)")
        let active = vm.vehiclesViewModel.activeVehicles.count
        let maint = vm.vehiclesViewModel.maintenanceVehicles.count
        lines.append("Active,\(active)")
        lines.append("In Maintenance,\(maint)")
        lines.append("")
        lines.append("Monthly Utilization")
        lines.append("Month,Vehicles Used,Total Vehicles")
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM yyyy"
        for data in vm.fleetUtilizationByMonth {
            lines.append("\(fmt.string(from: data.monthStart)),\(data.vehiclesUsed),\(vm.totalVehiclesCount)")
        }
        lines.append("")
        lines.append("Vehicle Trip Counts")
        lines.append("Vehicle,Make/Model,Trips")
        for item in vm.vehicleUtilization {
            lines.append("\(item.vehicle.licencePlate),\(item.vehicle.make) \(item.vehicle.model),\(item.tripCount)")
        }
    }

    private static func csvDriverPerformance(_ lines: inout [String], _ vm: ReportsViewModel) {
        lines.append("Summary")
        lines.append("Metric,Value")
        let active = vm.driverPerformance.filter { $0.tripCount > 0 }.count
        lines.append("Active Drivers,\(active)")
        lines.append("Total Trips,\(vm.totalFilteredTrips)")
        lines.append("Average Score,\(vm.averageDriverScore)")
        lines.append("Total Drivers,\(vm.usersViewModel.drivers.count)")
        lines.append("")
        lines.append("Driver Breakdown")
        lines.append("Name,Licence,Trips,Overall Score")
        for item in vm.driverPerformance {
            let name = item.user?.displayName ?? "Unknown"
            let score = vm.usersViewModel.driverScore(for: item.driver.id).map(\.overallScore).map(Int.init) ?? 75
            lines.append("\(csvEscaped(name)),\(item.driver.licenceNum),\(item.tripCount),\(score)")
        }
    }

    private static func csvVehicleHealth(_ lines: inout [String], _ vm: ReportsViewModel) {
        let scores = vm.vehicleHealthScores
        let avg = scores.isEmpty ? 0 : scores.map(\.score).reduce(0, +) / scores.count
        let good = scores.filter { $0.score >= 70 }.count
        let fair = scores.filter { $0.score >= 40 && $0.score < 70 }.count
        let poor = scores.filter { $0.score < 40 }.count
        lines.append("Summary")
        lines.append("Metric,Value")
        lines.append("Average Score,\(avg)")
        lines.append("Good (70+),\(good)")
        lines.append("Fair (40-69),\(fair)")
        lines.append("Poor (<40),\(poor)")
        lines.append("")
        lines.append("Vehicle Breakdown")
        lines.append("Vehicle,Make/Model,Score")
        for item in scores {
            lines.append("\(item.vehicle.licencePlate),\(item.vehicle.make) \(item.vehicle.model),\(item.score)")
        }
    }

    private static func csvMaintenance(_ lines: inout [String], _ vm: ReportsViewModel) {
        lines.append("Summary")
        lines.append("Metric,Value")
        lines.append("Total Cost,\(vm.maintenanceCostTotal.formatted(.currency(code: "INR")))")
        lines.append("Parts Cost,\(vm.maintenancePartsTotal.formatted(.currency(code: "INR")))")
        lines.append("Labour Cost,\(vm.maintenanceLabourTotal.formatted(.currency(code: "INR")))")
        lines.append("Completed,\(vm.filteredCompletedTasks.count)")
        lines.append("")
        lines.append("Longest Work Orders")
        lines.append("Task,Hours")
        for item in vm.longestWorkOrders {
            lines.append("\(csvEscaped(item.task.displayTitle)),\(String(format: "%.1f", item.hours))")
        }
        lines.append("")
        lines.append("Most Expensive Work Orders")
        lines.append("Task,Cost")
        for item in vm.mostExpensiveWorkOrders {
            lines.append("\(csvEscaped(item.task.displayTitle)),\(item.cost.formatted(.currency(code: "INR")))")
        }
    }

    private static func csvEscaped(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    // MARK: - PDF

    private final class PDFContext {
        var y: CGFloat = 40
        let ctx: UIGraphicsPDFRendererContext

        init(ctx: UIGraphicsPDFRendererContext) {
            self.ctx = ctx
        }

        func drawText(_ text: String, _ font: UIFont = .systemFont(ofSize: 11), _ color: UIColor = .black, _ x: CGFloat = 50) {
            (text as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: [.font: font, .foregroundColor: color])
        }

        func advance(_ by: CGFloat = 18) {
            y += by
        }

        func newPageIfNeeded(_ needed: CGFloat) {
            if y + needed > 760 {
                ctx.beginPage()
                y = 40
            }
        }

        func sectionHeader(_ title: String) {
            drawText(title, .boldSystemFont(ofSize: 14), .darkGray)
            advance(4)
            UIColor.systemGray4.setFill()
            UIRectFill(CGRect(x: 50, y: y - 3, width: 512, height: 1))
            advance(16)
        }
    }

    static func pdfData(for reportType: ReportType, viewModel: ReportsViewModel) -> Data {
        let fmt = UIGraphicsPDFRendererFormat()
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: fmt)
        return renderer.pdfData { ctx in
            let pc = PDFContext(ctx: ctx)
            pc.ctx.beginPage()
            pc.drawText(reportType.rawValue, .boldSystemFont(ofSize: 22))
            pc.advance(8)
            pc.drawText("Period: \(viewModel.selectedPeriod.rawValue)", .systemFont(ofSize: 13), .darkGray)
            pc.advance(20)

            switch reportType {
            case .trip: pdfTripReport(pc, viewModel)
            case .expenditure: pdfExpenditure(pc, viewModel)
            case .fleetUtilization: pdfFleetUtilization(pc, viewModel)
            case .driverPerformance: pdfDriverPerformance(pc, viewModel)
            case .vehicleHealth: pdfVehicleHealth(pc, viewModel)
            case .maintenance: pdfMaintenance(pc, viewModel)
            }
        }
    }

    private static func pdfTripReport(_ pc: PDFContext, _ vm: ReportsViewModel) {
        let total = vm.totalFilteredTrips
        let completed = vm.totalFilteredCompletedTrips
        let totalCost = vm.filteredTripCostTotal
        let avgCost = completed > 0 ? totalCost / Double(completed) : 0
        pc.sectionHeader("Summary")
        pc.newPageIfNeeded(40)
        pc.drawText("Total Trips: \(total)    Completed: \(completed)    Total Cost: \(totalCost.formatted(.currency(code: "INR")))    Avg Cost/Trip: \(avgCost.formatted(.currency(code: "INR")))", .systemFont(ofSize: 11), .black, 50)
        pc.advance(18)
        pc.sectionHeader("Trip Details")
        pc.newPageIfNeeded(80)
        pc.drawText("Date       Start                          End                            Status     Fuel       Total", .boldSystemFont(ofSize: 10), .darkGray, 50)
        pc.advance(4)
        for t in vm.filteredTrips {
            pc.newPageIfNeeded(16)
            let fuelStr = (t.fuelCost ?? 0).formatted(.currency(code: "INR"))
            let totalStr = t.totalCost.formatted(.currency(code: "INR"))
            pc.drawText("\(shortDateStr(t.startTime))  \(t.startLocation.prefix(25))  \(t.endLocation.prefix(25))  \(t.status.title.prefix(8))  \(fuelStr)  \(totalStr)", .systemFont(ofSize: 9), .black, 50)
            pc.advance(14)
        }
        pc.advance(8)
        pc.sectionHeader("Punctuality")
        let onTime = vm.onTimeTrips.count
        let delayed = vm.delayedTrips.count
        let rate = (onTime + delayed) > 0 ? Double(onTime) / Double(onTime + delayed) * 100 : 0
        pc.drawText("On-Time: \(onTime)  |  Delayed: \(delayed)  |  Rate: \(Int(rate.rounded()))%", .systemFont(ofSize: 11), .black, 50)
    }

    private static func pdfExpenditure(_ pc: PDFContext, _ vm: ReportsViewModel) {
        pc.sectionHeader("Summary")
        pc.newPageIfNeeded(60)
        pc.drawText("Total: \(vm.totalExpenditure.formatted(.currency(code: "INR")))", .systemFont(ofSize: 11), .black, 50); pc.advance(18)
        pc.drawText("Maintenance: \(vm.maintenanceCostTotal.formatted(.currency(code: "INR")))", .systemFont(ofSize: 11), .black, 50); pc.advance(18)
        pc.drawText("Fuel: \(vm.filteredTripFuelTotal.formatted(.currency(code: "INR")))", .systemFont(ofSize: 11), .black, 50); pc.advance(18)
        pc.drawText("Misc: \(vm.filteredTripMiscTotal.formatted(.currency(code: "INR")))", .systemFont(ofSize: 11), .black, 50); pc.advance(18)
        pc.advance(8)
        pc.sectionHeader("Top Work Orders")
        for item in vm.mostExpensiveWorkOrders.prefix(10) {
            pc.newPageIfNeeded(16)
            pc.drawText("\(item.task.displayTitle)  —  \(item.cost.formatted(.currency(code: "INR")))", .systemFont(ofSize: 10), .black, 50)
            pc.advance(14)
        }
    }

    private static func pdfFleetUtilization(_ pc: PDFContext, _ vm: ReportsViewModel) {
        pc.sectionHeader("Summary")
        pc.newPageIfNeeded(60)
        let active = vm.vehiclesViewModel.activeVehicles.count
        let maint = vm.vehiclesViewModel.maintenanceVehicles.count
        pc.drawText("Total Vehicles: \(vm.totalVehiclesCount)", .systemFont(ofSize: 11), .black, 50); pc.advance(18)
        pc.drawText("Active: \(active)", .systemFont(ofSize: 11), .black, 50); pc.advance(18)
        pc.drawText("In Maintenance: \(maint)", .systemFont(ofSize: 11), .black, 50); pc.advance(18)
        pc.advance(8)
        pc.sectionHeader("Vehicle Trip Counts")
        for item in vm.vehicleUtilization {
            pc.newPageIfNeeded(16)
            pc.drawText("\(item.vehicle.licencePlate) (\(item.vehicle.make) \(item.vehicle.model))  —  \(item.tripCount) trips", .systemFont(ofSize: 10), .black, 50)
            pc.advance(14)
        }
    }

    private static func pdfDriverPerformance(_ pc: PDFContext, _ vm: ReportsViewModel) {
        pc.sectionHeader("Summary")
        pc.newPageIfNeeded(60)
        let active = vm.driverPerformance.filter { $0.tripCount > 0 }.count
        pc.drawText("Active Drivers: \(active)    Total Trips: \(vm.totalFilteredTrips)", .systemFont(ofSize: 11), .black, 50); pc.advance(18)
        pc.drawText("Average Score: \(vm.averageDriverScore)    Total Drivers: \(vm.usersViewModel.drivers.count)", .systemFont(ofSize: 11), .black, 50); pc.advance(18)
        pc.advance(8)
        pc.sectionHeader("Driver Breakdown")
        for item in vm.driverPerformance {
            pc.newPageIfNeeded(16)
            let name = item.user?.displayName ?? "Unknown"
            let score = vm.usersViewModel.driverScore(for: item.driver.id).map(\.overallScore).map(Int.init) ?? 75
            pc.drawText("\(name) (Licence: \(item.driver.licenceNum))  —  \(item.tripCount) trips, Score: \(score)", .systemFont(ofSize: 10), .black, 50)
            pc.advance(14)
        }
    }

    private static func pdfVehicleHealth(_ pc: PDFContext, _ vm: ReportsViewModel) {
        let scores = vm.vehicleHealthScores
        let avg = scores.isEmpty ? 0 : scores.map(\.score).reduce(0, +) / scores.count
        let good = scores.filter { $0.score >= 70 }.count
        let fair = scores.filter { $0.score >= 40 && $0.score < 70 }.count
        let poor = scores.filter { $0.score < 40 }.count
        pc.sectionHeader("Summary")
        pc.newPageIfNeeded(60)
        pc.drawText("Average Score: \(avg)    Good (70+): \(good)    Fair (40-69): \(fair)    Poor (<40): \(poor)", .systemFont(ofSize: 11), .black, 50); pc.advance(18)
        pc.advance(8)
        pc.sectionHeader("Vehicle Breakdown")
        for item in scores {
            pc.newPageIfNeeded(16)
            pc.drawText("\(item.vehicle.licencePlate) (\(item.vehicle.make) \(item.vehicle.model))  —  Score: \(item.score)", .systemFont(ofSize: 10), .black, 50)
            pc.advance(14)
        }
    }

    private static func pdfMaintenance(_ pc: PDFContext, _ vm: ReportsViewModel) {
        pc.sectionHeader("Summary")
        pc.newPageIfNeeded(60)
        pc.drawText("Total Cost: \(vm.maintenanceCostTotal.formatted(.currency(code: "INR")))", .systemFont(ofSize: 11), .black, 50); pc.advance(18)
        pc.drawText("Parts: \(vm.maintenancePartsTotal.formatted(.currency(code: "INR")))", .systemFont(ofSize: 11), .black, 50); pc.advance(18)
        pc.drawText("Labour: \(vm.maintenanceLabourTotal.formatted(.currency(code: "INR")))", .systemFont(ofSize: 11), .black, 50); pc.advance(18)
        pc.drawText("Completed: \(vm.filteredCompletedTasks.count)", .systemFont(ofSize: 11), .black, 50); pc.advance(18)
        pc.advance(8)
        pc.sectionHeader("Longest Work Orders")
        for item in vm.longestWorkOrders.prefix(10) {
            pc.newPageIfNeeded(16)
            pc.drawText("\(item.task.displayTitle)  —  \(String(format: "%.1f", item.hours)) hrs", .systemFont(ofSize: 10), .black, 50)
            pc.advance(14)
        }
        pc.advance(8)
        pc.sectionHeader("Most Expensive Work Orders")
        for item in vm.mostExpensiveWorkOrders.prefix(10) {
            pc.newPageIfNeeded(16)
            pc.drawText("\(item.task.displayTitle)  —  \(item.cost.formatted(.currency(code: "INR")))", .systemFont(ofSize: 10), .black, 50)
            pc.advance(14)
        }
    }
}

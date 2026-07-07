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
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let dateStr = df.string(from: Date())
        switch self {
        case .trip: return "Trip Report\(dateStr)"
        case .expenditure: return "Expenditure Report\(dateStr)"
        case .fleetUtilization: return "Fleet Utilization\(dateStr)"
        case .driverPerformance: return "Driver Performance\(dateStr)"
        case .vehicleHealth: return "Vehicle Health\(dateStr)"
        case .maintenance: return "Maintenance Report\(dateStr)"
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
        var y: CGFloat = 60
        let ctx: UIGraphicsPDFRendererContext
        var pageNumber: Int = 1

        let margin: CGFloat = 50
        let pageWidth: CGFloat = 612
        let contentWidth: CGFloat = 512
        let accentColor = UIColor(red: 0.19, green: 0.46, blue: 0.91, alpha: 1.0)
        let successColor = UIColor(red: 0.22, green: 0.73, blue: 0.44, alpha: 1.0)
        let warningColor = UIColor(red: 0.95, green: 0.61, blue: 0.14, alpha: 1.0)
        let dangerColor = UIColor(red: 0.86, green: 0.25, blue: 0.28, alpha: 1.0)
        let lightBg = UIColor(red: 0.97, green: 0.97, blue: 0.98, alpha: 1.0)
        let headerBg = UIColor(red: 0.19, green: 0.46, blue: 0.91, alpha: 0.85)

        init(ctx: UIGraphicsPDFRendererContext) {
            self.ctx = ctx
        }

        func drawText(_ text: String, _ font: UIFont = .systemFont(ofSize: 11), _ color: UIColor = .black, _ x: CGFloat? = nil) {
            let xPos = x ?? margin
            (text as NSString).draw(at: CGPoint(x: xPos, y: y), withAttributes: [.font: font, .foregroundColor: color])
        }

        func advance(_ by: CGFloat = 18) {
            y += by
        }

        func newPageIfNeeded(_ needed: CGFloat) {
            if y + needed > 740 {
                drawFooter()
                ctx.beginPage()
                pageNumber += 1
                y = 50
            }
        }

        func drawFooter() {
            let footerText = "Fleet Management System  ·  Page \(pageNumber)"
            (footerText as NSString).draw(at: CGPoint(x: margin, y: 770), withAttributes: [.font: UIFont.systemFont(ofSize: 9), .foregroundColor: UIColor.lightGray])
        }

        func drawHeaderBar(title: String, subtitle: String) {
            UIColor(red: 0.12, green: 0.14, blue: 0.17, alpha: 1.0).setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: pageWidth, height: 100))

            let titleAttr: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 22), .foregroundColor: UIColor.white]
            (title as NSString).draw(at: CGPoint(x: margin, y: 28), withAttributes: titleAttr)

            let subAttr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 12), .foregroundColor: UIColor(white: 0.8, alpha: 1.0)]
            (subtitle as NSString).draw(at: CGPoint(x: margin, y: 58), withAttributes: subAttr)

            accentColor.setFill()
            UIRectFill(CGRect(x: margin, y: 82, width: 60, height: 3))
            y = 120
        }

        func drawSectionTitle(_ title: String) {
            newPageIfNeeded(36)
            drawText(title.uppercased(), .boldSystemFont(ofSize: 13), accentColor)
            advance(4)
            accentColor.withAlphaComponent(0.3).setFill()
            UIRectFill(CGRect(x: margin, y: y - 2, width: contentWidth, height: 1))
            advance(14)
        }

        func drawKpiCard(title: String, value: String, color: UIColor, x: CGFloat, cardWidth: CGFloat) {
            let cardRect = CGRect(x: x, y: y, width: cardWidth, height: 52)
            color.withAlphaComponent(0.1).setFill()
            UIBezierPath(roundedRect: cardRect, cornerRadius: 6).fill()
            color.setFill()
            UIRectFill(CGRect(x: cardRect.minX, y: cardRect.minY, width: 3, height: cardRect.height))
            let valAttr: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 16), .foregroundColor: color]
            (value as NSString).draw(at: CGPoint(x: x + 12, y: y + 6), withAttributes: valAttr)
            let lblAttr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.darkGray]
            (title as NSString).draw(at: CGPoint(x: x + 12, y: y + 30), withAttributes: lblAttr)
        }

        func drawKpiRow(cards: [(title: String, value: String, color: UIColor)]) {
            let count = max(cards.count, 1)
            let totalGap: CGFloat = CGFloat(count - 1) * 8
            let cardWidth = (contentWidth - totalGap) / CGFloat(count)
            for (i, card) in cards.enumerated() {
                let x = margin + CGFloat(i) * (cardWidth + 8)
                drawKpiCard(title: card.title, value: card.value, color: card.color, x: x, cardWidth: cardWidth)
            }
            y += 60
        }

        func drawTableHeader(columns: [(text: String, width: CGFloat)]) {
            let headerColor = UIColor(red: 0.19, green: 0.46, blue: 0.91, alpha: 0.12)
            headerColor.setFill()
            let h: CGFloat = 24
            UIRectFill(CGRect(x: margin, y: y, width: contentWidth, height: h))
            var xPos = margin + 8
            for col in columns {
                let attr: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 9), .foregroundColor: accentColor]
                (col.text as NSString).draw(at: CGPoint(x: xPos, y: y + 5), withAttributes: attr)
                xPos += col.width
            }
            y += h
        }

        func drawTableRow(columns: [(text: String, width: CGFloat)], isEven: Bool) {
            newPageIfNeeded(22)
            if isEven {
                lightBg.setFill()
                UIRectFill(CGRect(x: margin, y: y, width: contentWidth, height: 20))
            }
            UIColor(white: 0.85, alpha: 1.0).setFill()
            UIRectFill(CGRect(x: margin, y: y + 20, width: contentWidth, height: 0.5))
            var xPos = margin + 8
            for col in columns {
                let attr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9), .foregroundColor: UIColor.darkGray]
                let display = (col.text as NSString).length > Int(col.width / 6) ? String((col.text as NSString).substring(to: min((col.text as NSString).length, Int(col.width / 6.5)))) + "…" : col.text
                (display as NSString).draw(at: CGPoint(x: xPos, y: y + 3), withAttributes: attr)
                xPos += col.width
            }
            y += 21
        }

        func drawDivider() {
            UIColor(white: 0.88, alpha: 1.0).setFill()
            UIRectFill(CGRect(x: margin, y: y, width: contentWidth, height: 1))
            advance(12)
        }
    }

    static func pdfData(for reportType: ReportType, viewModel: ReportsViewModel) -> Data {
        let fmt = UIGraphicsPDFRendererFormat()
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: fmt)
        return renderer.pdfData { ctx in
            let pc = PDFContext(ctx: ctx)
            let df = DateFormatter()
            df.dateStyle = .medium
            pc.ctx.beginPage()

            let periodText = "Period: \(viewModel.selectedPeriod.rawValue)  ·  Generated: \(df.string(from: Date()))"
            pc.drawHeaderBar(title: reportType.rawValue, subtitle: periodText)

            switch reportType {
            case .trip: pdfTripReport(pc, viewModel)
            case .expenditure: pdfExpenditure(pc, viewModel)
            case .fleetUtilization: pdfFleetUtilization(pc, viewModel)
            case .driverPerformance: pdfDriverPerformance(pc, viewModel)
            case .vehicleHealth: pdfVehicleHealth(pc, viewModel)
            case .maintenance: pdfMaintenance(pc, viewModel)
            }

            pc.drawFooter()
        }
    }

    private static func pdfTripReport(_ pc: PDFContext, _ vm: ReportsViewModel) {
        let total = vm.totalFilteredTrips
        let completed = vm.totalFilteredCompletedTrips
        let totalCost = vm.filteredTripCostTotal
        let avgCost = completed > 0 ? totalCost / Double(completed) : 0

        pc.drawKpiRow(cards: [
            ("Total Trips", "\(total)", pc.accentColor),
            ("Completed", "\(completed)", pc.successColor),
            ("Total Cost", totalCost.formatted(.currency(code: "INR")), pc.warningColor),
            ("Avg / Trip", avgCost.formatted(.currency(code: "INR")), pc.accentColor)
        ])

        pc.drawSectionTitle("Trip Details")
        let totCol: CGFloat = 70, dateCol: CGFloat = 70, locCol: CGFloat = 110, statusCol: CGFloat = 60, costCol: CGFloat = 70
        pc.drawTableHeader(columns: [
            ("Date", dateCol), ("From", locCol), ("To", locCol),
            ("Status", statusCol), ("Fuel", costCol), ("Total", totCol)
        ])
        for (i, t) in vm.filteredTrips.enumerated() {
            let fuelStr = (t.fuelCost ?? 0).formatted(.currency(code: "INR"))
            let totalStr = t.totalCost.formatted(.currency(code: "INR"))
            pc.drawTableRow(columns: [
                (shortDateStr(t.startTime), dateCol),
                (t.startLocation, locCol),
                (t.endLocation, locCol),
                (t.status.title, statusCol),
                (fuelStr, costCol),
                (totalStr, totCol)
            ], isEven: i % 2 == 0)
        }
        pc.advance(4)

        pc.drawSectionTitle("Punctuality")
        let onTime = vm.onTimeTrips.count
        let delayed = vm.delayedTrips.count
        let totalPunctuality = onTime + delayed
        let punctualityRate = totalPunctuality > 0 ? Double(onTime) / Double(totalPunctuality) * 100 : 0
        let rateColor = punctualityRate >= 70 ? pc.successColor : pc.warningColor
        pc.drawKpiRow(cards: [
            ("On-Time Trips", "\(onTime)", pc.successColor),
            ("Delayed Trips", "\(delayed)", pc.dangerColor),
            ("Punctuality Rate", "\(Int(punctualityRate.rounded()))%", rateColor)
        ])
    }

    private static func pdfExpenditure(_ pc: PDFContext, _ vm: ReportsViewModel) {
        let total = vm.totalExpenditure
        let maint = vm.maintenanceCostTotal
        let fuel = vm.filteredTripFuelTotal
        let misc = vm.filteredTripMiscTotal

        pc.drawKpiRow(cards: [
            ("Total Expenditure", total.formatted(.currency(code: "INR")), pc.dangerColor),
            ("Maintenance", maint.formatted(.currency(code: "INR")), pc.warningColor),
            ("Fuel", fuel.formatted(.currency(code: "INR")), pc.accentColor),
            ("Misc", misc.formatted(.currency(code: "INR")), pc.successColor)
        ])

        let items = vm.mostExpensiveWorkOrders.prefix(10)
        if !items.isEmpty {
            pc.drawSectionTitle("Top Work Orders by Cost")
            let taskCol: CGFloat = 340, costCol: CGFloat = 120
            pc.drawTableHeader(columns: [("Task", taskCol), ("Cost", costCol)])
            for (i, item) in items.enumerated() {
                pc.drawTableRow(columns: [
                    (item.task.displayTitle, taskCol),
                    (item.cost.formatted(.currency(code: "INR")), costCol)
                ], isEven: i % 2 == 0)
            }
            pc.advance(4)
        }

        let fuelItems = vm.topTripsByFuelCost.prefix(10)
        if !fuelItems.isEmpty {
            pc.drawSectionTitle("Top Trips by Fuel Cost")
            let tripCol: CGFloat = 340, fcostCol: CGFloat = 120
            pc.drawTableHeader(columns: [("Trip", tripCol), ("Fuel Cost", fcostCol)])
            for (i, item) in fuelItems.enumerated() {
                pc.drawTableRow(columns: [
                    ("\(item.trip.startLocation) → \(item.trip.endLocation)", tripCol),
                    (item.cost.formatted(.currency(code: "INR")), fcostCol)
                ], isEven: i % 2 == 0)
            }
        }
    }

    private static func pdfFleetUtilization(_ pc: PDFContext, _ vm: ReportsViewModel) {
        let totalVehicles = vm.totalVehiclesCount
        let active = vm.vehiclesViewModel.activeVehicles.count
        let maint = vm.vehiclesViewModel.maintenanceVehicles.count
        let used = vm.vehiclesUsedThisPeriod
        let utilPct = totalVehicles > 0 ? Double(used) / Double(totalVehicles) * 100 : 0

        pc.drawKpiRow(cards: [
            ("Total Vehicles", "\(totalVehicles)", pc.accentColor),
            ("Active", "\(active)", pc.successColor),
            ("In Maintenance", "\(maint)", pc.warningColor),
            ("Utilization", "\(Int(utilPct.rounded()))%", pc.accentColor)
        ])

        let items = vm.vehicleUtilization
        if !items.isEmpty {
            pc.drawSectionTitle("Vehicle Trip Counts")
            let vehicleCol: CGFloat = 200, modelCol: CGFloat = 150, tripsCol: CGFloat = 80
            pc.drawTableHeader(columns: [
                ("Vehicle", vehicleCol), ("Make / Model", modelCol), ("Trips", tripsCol)
            ])
            for (i, item) in items.enumerated() {
                pc.drawTableRow(columns: [
                    (item.vehicle.licencePlate, vehicleCol),
                    ("\(item.vehicle.make) \(item.vehicle.model)", modelCol),
                    ("\(item.tripCount)", tripsCol)
                ], isEven: i % 2 == 0)
            }
            pc.advance(4)
        }

        if vm.fleetUtilizationByMonth.count > 1 {
            pc.drawSectionTitle("Monthly Utilization Trend")
            let monthCol: CGFloat = 200, usedCol: CGFloat = 150, pctCol: CGFloat = 100
            pc.drawTableHeader(columns: [("Month", monthCol), ("Vehicles Used", usedCol), ("% of Fleet", pctCol)])
            let fmt = DateFormatter()
            fmt.dateFormat = "MMM yyyy"
            for (i, data) in vm.fleetUtilizationByMonth.enumerated() {
                let pct = totalVehicles > 0 ? Double(data.vehiclesUsed) / Double(totalVehicles) * 100 : 0
                pc.drawTableRow(columns: [
                    (fmt.string(from: data.monthStart), monthCol),
                    ("\(data.vehiclesUsed) / \(totalVehicles)", usedCol),
                    ("\(Int(pct.rounded()))%", pctCol)
                ], isEven: i % 2 == 0)
            }
        }
    }

    private static func pdfDriverPerformance(_ pc: PDFContext, _ vm: ReportsViewModel) {
        let active = vm.driverPerformance.filter { $0.tripCount > 0 }.count
        let total = vm.usersViewModel.drivers.count
        let avgScore = vm.averageDriverScore

        pc.drawKpiRow(cards: [
            ("Active Drivers", "\(active)", pc.successColor),
            ("Total Drivers", "\(total)", pc.accentColor),
            ("Avg Score", "\(avgScore)", avgScore >= 70 ? pc.successColor : pc.warningColor),
            ("Total Trips", "\(vm.totalFilteredTrips)", pc.accentColor)
        ])

        if !vm.driverPerformance.isEmpty {
            pc.drawSectionTitle("Driver Breakdown")
            let nameCol: CGFloat = 150, licCol: CGFloat = 110, tripsCol: CGFloat = 60, scoreCol: CGFloat = 70
            pc.drawTableHeader(columns: [
                ("Name", nameCol), ("License", licCol), ("Trips", tripsCol), ("Score", scoreCol)
            ])
            for (i, item) in vm.driverPerformance.enumerated() {
                let name = item.user?.displayName ?? "Unknown"
                let score = vm.usersViewModel.driverScore(for: item.driver.id).map(\.overallScore).map(Int.init) ?? 75
                let scoreColor = score >= 70 ? pc.successColor : (score >= 40 ? pc.warningColor : pc.dangerColor)
                let scoreStr = "\(score)"
                pc.drawTableRow(columns: [
                    (name, nameCol),
                    (item.driver.licenceNum, licCol),
                    ("\(item.tripCount)", tripsCol),
                    (scoreStr, scoreCol)
                ], isEven: i % 2 == 0)
            }
        }
    }

    private static func pdfVehicleHealth(_ pc: PDFContext, _ vm: ReportsViewModel) {
        let scores = vm.vehicleHealthScores
        let avg = scores.isEmpty ? 0 : scores.map(\.score).reduce(0, +) / scores.count
        let good = scores.filter { $0.score >= 70 }.count
        let fair = scores.filter { $0.score >= 40 && $0.score < 70 }.count
        let poor = scores.filter { $0.score < 40 }.count

        pc.drawKpiRow(cards: [
            ("Average Score", "\(avg)", avg >= 70 ? pc.successColor : (avg >= 40 ? pc.warningColor : pc.dangerColor)),
            ("Good (70+)", "\(good)", pc.successColor),
            ("Fair (40-69)", "\(fair)", pc.warningColor),
            ("Poor (<40)", "\(poor)", pc.dangerColor)
        ])

        if !scores.isEmpty {
            pc.drawSectionTitle("Vehicle Breakdown")
            let vehicleCol: CGFloat = 150, modelCol: CGFloat = 150, scoreCol: CGFloat = 80
            pc.drawTableHeader(columns: [
                ("Vehicle", vehicleCol), ("Make / Model", modelCol), ("Score", scoreCol)
            ])
            for (i, item) in scores.enumerated() {
                let scoreColor = item.score >= 70 ? pc.successColor : (item.score >= 40 ? pc.warningColor : pc.dangerColor)
                let scoreStr = "\(item.score)"
                pc.drawTableRow(columns: [
                    (item.vehicle.licencePlate, vehicleCol),
                    ("\(item.vehicle.make) \(item.vehicle.model)", modelCol),
                    (scoreStr, scoreCol)
                ], isEven: i % 2 == 0)
            }
        }
    }

    private static func pdfMaintenance(_ pc: PDFContext, _ vm: ReportsViewModel) {
        let totalCost = vm.maintenanceCostTotal
        let parts = vm.maintenancePartsTotal
        let labour = vm.maintenanceLabourTotal
        let completed = vm.filteredCompletedTasks.count

        pc.drawKpiRow(cards: [
            ("Total Cost", totalCost.formatted(.currency(code: "INR")), pc.dangerColor),
            ("Parts", parts.formatted(.currency(code: "INR")), pc.warningColor),
            ("Labour", labour.formatted(.currency(code: "INR")), pc.accentColor),
            ("Completed", "\(completed)", pc.successColor)
        ])

        let longest = vm.longestWorkOrders.prefix(10)
        if !longest.isEmpty {
            pc.drawSectionTitle("Longest Work Orders")
            let taskCol: CGFloat = 340, hoursCol: CGFloat = 100
            pc.drawTableHeader(columns: [("Task", taskCol), ("Hours", hoursCol)])
            for (i, item) in longest.enumerated() {
                pc.drawTableRow(columns: [
                    (item.task.displayTitle, taskCol),
                    ("\(String(format: "%.1f", item.hours)) hrs", hoursCol)
                ], isEven: i % 2 == 0)
            }
            pc.advance(4)
        }

        let expensive = vm.mostExpensiveWorkOrders.prefix(10)
        if !expensive.isEmpty {
            pc.drawSectionTitle("Most Expensive Work Orders")
            let taskCol: CGFloat = 340, costCol: CGFloat = 120
            pc.drawTableHeader(columns: [("Task", taskCol), ("Cost", costCol)])
            for (i, item) in expensive.enumerated() {
                pc.drawTableRow(columns: [
                    (item.task.displayTitle, taskCol),
                    (item.cost.formatted(.currency(code: "INR")), costCol)
                ], isEven: i % 2 == 0)
            }
        }
    }
}

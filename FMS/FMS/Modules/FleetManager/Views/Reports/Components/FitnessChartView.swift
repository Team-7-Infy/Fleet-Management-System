import SwiftUI
import Charts

// MARK: - Chart Data Types

struct TripWeekData: Identifiable {
    let id = UUID()
    let weekStart: Date
    let count: Int
}

struct TripMonthData: Identifiable {
    let id = UUID()
    let monthStart: Date
    let count: Int
}

struct TaskCostData: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let cost: Double
}

struct UtilizationData: Identifiable {
    let id = UUID()
    let label: String
    let value: Int
}

struct HealthScoreData: Identifiable {
    let id = UUID()
    let label: String
    let score: Int
    let band: String
}

struct ExpenditureSlice: Identifiable {
    let id = UUID()
    let label: String
    let amount: Double
    let color: Color
}

struct FleetUtilizationMonthData: Identifiable {
    let id = UUID()
    let monthStart: Date
    let vehiclesUsed: Int
}

// MARK: - Generic Fitness Bar Chart

struct FitnessBarChart<DataType: Identifiable>: View where DataType: Hashable {
    let data: [DataType]
    let xValue: KeyPath<DataType, String>
    let yValue: KeyPath<DataType, Double>
    let color: Color
    let height: CGFloat

    init(
        data: [DataType],
        xValue: KeyPath<DataType, String>,
        yValue: KeyPath<DataType, Double>,
        color: Color,
        height: CGFloat = 180
    ) {
        self.data = data
        self.xValue = xValue
        self.yValue = yValue
        self.color = color
        self.height = height
    }

    var body: some View {
        Chart(data) { item in
            BarMark(
                x: .value("Label", item[keyPath: xValue]),
                y: .value("Value", item[keyPath: yValue])
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(color.gradient)
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisGridLine().foregroundStyle(.quaternary)
                AxisValueLabel().font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic) { _ in
                AxisGridLine().foregroundStyle(.quaternary)
                AxisValueLabel().font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .chartPlotStyle { plot in
            plot.background(.quinary.opacity(0.3))
        }
        .frame(height: height)
    }
}

// MARK: - Monthly Bar Chart (shows all months in range, even 0)

struct FitnessMonthlyBarChart: View {
    let data: [TripMonthData]
    let color: Color

    private var chartDomain: ClosedRange<Date> {
        guard let first = data.first?.monthStart, let last = data.last?.monthStart else {
            return Date()...Date()
        }
        let calendar = Calendar.current
        let endOfLast = calendar.date(byAdding: .month, value: 1, to: last)!
        return first...endOfLast
    }

    var body: some View {
        Chart(data) { item in
            BarMark(
                x: .value("Month", item.monthStart, unit: .month),
                y: .value("Trips", item.count)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(color.gradient)
        }
        .chartXScale(domain: chartDomain)
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisGridLine().foregroundStyle(.quaternary)
                AxisValueLabel(format: .dateTime.month(.abbreviated))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic) { _ in
                AxisGridLine().foregroundStyle(.quaternary)
                AxisValueLabel().font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .chartPlotStyle { plot in
            plot.background(.quinary.opacity(0.3))
        }
        .frame(height: 180)
    }
}

// MARK: - Date Bar Chart (weekly)

struct FitnessDateBarChart: View {
    let data: [TripWeekData]
    let color: Color

    var body: some View {
        Chart(data) { item in
            BarMark(
                x: .value("Week", item.weekStart, unit: .weekOfYear),
                y: .value("Trips", item.count)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(color.gradient)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisGridLine().foregroundStyle(.quaternary)
                AxisValueLabel(format: .dateTime.month(.abbreviated))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic) { _ in
                AxisGridLine().foregroundStyle(.quaternary)
                AxisValueLabel().font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .chartPlotStyle { plot in
            plot.background(.quinary.opacity(0.3))
        }
        .frame(height: 180)
    }
}

// MARK: - Horizontal Bar Chart

struct FitnessHorizontalBarChart: View {
    let data: [UtilizationData]
    let color: Color

    var body: some View {
        Chart(data) { item in
            BarMark(
                x: .value("Value", item.value),
                y: .value("Label", item.label)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(color.gradient)
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisGridLine().foregroundStyle(.quaternary)
                AxisValueLabel().font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic) { _ in
                AxisValueLabel().font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .chartPlotStyle { plot in
            plot.background(.quinary.opacity(0.3))
        }
        .frame(height: 200)
    }
}

// MARK: - Health Score Chart

struct FitnessHealthChart: View {
    let data: [HealthScoreData]

    var body: some View {
        Chart(data) { item in
            BarMark(
                x: .value("Vehicle", item.label),
                y: .value("Score", item.score)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(by: .value("Band", item.band))
        }
        .chartForegroundStyleScale([
            "Good": FleetPalette.success,
            "Fair": FleetPalette.warning,
            "Poor": FleetPalette.danger
        ])
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisValueLabel().font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic) { _ in
                AxisGridLine().foregroundStyle(.quaternary)
                AxisValueLabel().font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .chartPlotStyle { plot in
            plot.background(.quinary.opacity(0.3))
        }
        .frame(height: 180)
    }
}

// MARK: - Pie Chart (Expenditure)

struct FitnessPieChart: View {
    let slices: [ExpenditureSlice]
    let height: CGFloat

    init(slices: [ExpenditureSlice], height: CGFloat = 200) {
        self.slices = slices
        self.height = height
    }

    var body: some View {
        VStack(spacing: 12) {
            Chart(slices) { slice in
                SectorMark(
                    angle: .value("Amount", slice.amount),
                    outerRadius: .inset(6)
                )
                .foregroundStyle(slice.color.gradient)
            }
            .frame(height: height)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 6) {
                ForEach(slices) { slice in
                    HStack(spacing: 6) {
                        Capsule()
                            .fill(slice.color)
                            .frame(width: 10, height: 10)
                        Text(slice.label)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(slice.amount.formatted(.currency(code: "INR")))
                            .font(.caption).bold()
                            .foregroundStyle(FleetPalette.textPrimary)
                    }
                }
            }
        }
    }
}

// MARK: - Line Chart (Fleet Utilization)

struct FitnessLineChart: View {
    let data: [FleetUtilizationMonthData]
    let totalVehicles: Int
    let color: Color

    private var chartDomain: ClosedRange<Date> {
        guard let first = data.first?.monthStart, let last = data.last?.monthStart else {
            return Date()...Date()
        }
        let calendar = Calendar.current
        let endOfLast = calendar.date(byAdding: .month, value: 1, to: last)!
        return first...endOfLast
    }

    var body: some View {
        Chart(data) { item in
            LineMark(
                x: .value("Month", item.monthStart, unit: .month),
                y: .value("Vehicles Used", item.vehiclesUsed)
            )
            .foregroundStyle(color.gradient)
            .lineStyle(StrokeStyle(lineWidth: 2.5))

            PointMark(
                x: .value("Month", item.monthStart, unit: .month),
                y: .value("Vehicles Used", item.vehiclesUsed)
            )
            .foregroundStyle(color)
            .symbolSize(24)
        }
        .clipped()
        .chartXScale(domain: chartDomain)
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisGridLine().foregroundStyle(.quaternary)
                AxisValueLabel(format: .dateTime.month(.abbreviated))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic) { _ in
                AxisGridLine().foregroundStyle(.quaternary)
                AxisValueLabel().font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .chartYScale(domain: 0...totalVehicles)
        .chartPlotStyle { plot in
            plot.background(.quinary.opacity(0.3))
        }
        .frame(height: 180)
    }
}

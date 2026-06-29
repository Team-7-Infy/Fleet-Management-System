import Foundation
import Combine

final class ActivityHistoryViewModel: ObservableObject {
    @Published private(set) var activities: [Activity] = []
    @Published private(set) var state: LoadableState<Void> = .idle

    private let workOrderService: any WorkOrderServicing

    init(dependencies: AppDependencyContainer) {
        workOrderService = dependencies.workOrderService
    }

    func load() async {
        state = .loading
        do {
            let workOrders = try await workOrderService.assignedWorkOrders()
            let relevantOrders = workOrders.filter { $0.status == .completed || $0.status == .inProgress }
            activities = relevantOrders.map { order in
                Activity(
                    id: order.id.uuidString,
                    title: order.title,
                    subtitle: order.vehicleName,
                    date: order.dueDate, // or completion date if available
                    status: order.status,
                    elapsedTime: order.elapsedTime
                )
            }.sorted { $0.date > $1.date }
            
            state = .loaded(())
        } catch let error as AppError {
            state = .failed(error)
        } catch {
            state = .failed(.unknown(error.localizedDescription))
        }
    }
    
    var groupedActivities: [(header: String, activities: [Activity])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: activities) { activity in
            calendar.startOfDay(for: activity.date)
        }
        
        let sortedDates = grouped.keys.sorted(by: >)
        
        return sortedDates.map { date in
            let header: String
            if calendar.isDateInToday(date) {
                header = "Today"
            } else if calendar.isDateInYesterday(date) {
                header = "Yesterday"
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                header = formatter.string(from: date)
            }
            
            return (header, grouped[date] ?? [])
        }
    }
}

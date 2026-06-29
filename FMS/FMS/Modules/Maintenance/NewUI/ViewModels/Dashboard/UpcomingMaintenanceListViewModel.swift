import Foundation
import Combine

final class UpcomingMaintenanceListViewModel: ObservableObject {
    @Published private(set) var vehicles: [Vehicle] = []
    @Published private(set) var workOrders: [WorkOrder] = []
    @Published private(set) var state: LoadableState<Void> = .idle

    private let vehicleService: any VehicleServicing
    private let workOrderService: any WorkOrderServicing
    private let authService: any AuthServicing
    private var cancellables = Set<AnyCancellable>()

    init(dependencies: AppDependencyContainer) {
        vehicleService = dependencies.vehicleService
        workOrderService = dependencies.workOrderService
        authService = dependencies.authService
        
        NotificationCenter.default.publisher(for: NSNotification.Name("WorkOrderUpdated"))
            .debounce(for: .seconds(0.3), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.load(isRefresh: true)
                }
            }
            .store(in: &cancellables)
    }

    @MainActor
    func load(isRefresh: Bool = false) async {
        if !isRefresh { state = .loading }
        do {
            let user = try? await authService.currentUser()
            let allWorkOrders = try await workOrderService.assignedWorkOrders()
            workOrders = allWorkOrders.filter { $0.executedBy == user?.personnelId }
            vehicles = try await vehicleService.vehiclesNeedingAttention()
            state = .loaded(())
        } catch let error as AppError {
            state = .failed(error)
        } catch {
            state = .failed(.unknown(error.localizedDescription))
        }
    }
    
    struct DaySchedule: Identifiable {
        let id = UUID()
        let dayName: String
        let date: Date
        let workOrders: [DashboardWorkOrder]
    }
    
    var weeklySchedule: [DaySchedule] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var schedule: [DaySchedule] = []
        
        for i in 0..<7 {
            guard let scheduleDate = calendar.date(byAdding: .day, value: i, to: today) else { continue }
            
            let dayName = i == 0 ? "Today" : (i == 1 ? "Tomorrow" : scheduleDate.formatted(.dateTime.weekday(.wide)))
            
            // Find work orders due on this schedule date
            let activeOrders = workOrders.filter { $0.status.isStartable }
            let dayOrders = activeOrders.filter { calendar.isDate($0.dueDate, inSameDayAs: scheduleDate) }
            
            if !dayOrders.isEmpty {
                let dashboardOrders = dayOrders.map { order in
                    let vehicle = vehicles.first(where: { $0.id.uuidString == order.vehicleID })
                    return DashboardWorkOrder(workOrder: order, vehicle: vehicle)
                }.sorted {
                    if $0.workOrder.isUrgent == true && $1.workOrder.isUrgent != true {
                        return true
                    } else if $0.workOrder.isUrgent != true && $1.workOrder.isUrgent == true {
                        return false
                    } else {
                        return $0.workOrder.dueDate < $1.workOrder.dueDate
                    }
                }
                
                schedule.append(DaySchedule(dayName: dayName, date: scheduleDate, workOrders: dashboardOrders))
            }
        }
        
        return schedule
    }
}

private extension JobStatus {
    var isStartable: Bool {
        self == .pending || self == .assigned
    }
}

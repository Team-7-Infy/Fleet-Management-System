import Foundation
import Combine

final class MPDashboardViewModel: ObservableObject {
    @Published private(set) var user: UserProfile?
    @Published private(set) var vehicles: [Vehicle] = []
    @Published private(set) var workOrders: [WorkOrder] = []
    @Published private(set) var upcomingServices: [ServiceRecord] = []
    @Published private(set) var activities: [Activity] = []
    @Published private(set) var state: LoadableState<Void> = .idle

    private let authService: any AuthServicing
    private let vehicleService: any VehicleServicing
    private let workOrderService: any WorkOrderServicing
    
    private var cancellables = Set<AnyCancellable>()

    init(dependencies: AppDependencyContainer) {
        authService = dependencies.authService
        vehicleService = dependencies.vehicleService
        workOrderService = dependencies.workOrderService
        
        
        NotificationCenter.default.publisher(for: NSNotification.Name("UserProfileUpdated"))
            .sink { [weak self] _ in
                Task {
                    await self?.reloadUser()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: NSNotification.Name("WorkOrderUpdated"))
            .sink { [weak self] _ in
                Task {
                    await self?.load(isRefresh: true)
                }
            }
            .store(in: &cancellables)
    }
    
    private func reloadUser() async {
        if let updatedUser = try? await authService.currentUser() {
            await MainActor.run {
                self.user = updatedUser
            }
        }
    }

    func load(isRefresh: Bool = false) async {
        if !isRefresh { state = .loading }
        do {
            if let currentUser = try? await authService.currentUser() {
                user = currentUser
            }
            vehicles = try await vehicleService.vehiclesNeedingAttention()
            let allWorkOrders = try await workOrderService.assignedWorkOrders()
            
            // Only show work orders assigned to the current user
            workOrders = allWorkOrders.filter { $0.executedBy == user?.personnelId }
            
            // Map my completed and inProgress workOrders to activities
            let relevantOrders = workOrders.filter { $0.status == .completed || $0.status == .inProgress }
            activities = relevantOrders.map { order in
                let vehicle = vehicles.first(where: { $0.id.uuidString == order.vehicleID })
                let subtitle = vehicle?.registrationNumber ?? order.vehicleName
                return Activity(
                    id: order.id.uuidString,
                    title: order.title,
                    subtitle: subtitle,
                    date: order.dueDate,
                    status: order.status,
                    elapsedTime: order.elapsedTime
                )
            }.sorted { $0.date > $1.date }
            
            upcomingServices = try await workOrderService.scheduledServices()
            state = .loaded(())
        } catch let error as AppError {
            state = .failed(error)
        } catch {
            state = .failed(.unknown(error.localizedDescription))
        }
    }
    
    var inProgressCount: Int {
        workOrders.filter { $0.status == .inProgress }.count
    }
    
    var completedCount: Int {
        workOrders.filter { $0.status == .completed }.count
    }
    
    var remainingCount: Int {
        workOrders.filter { $0.status.isStartable }.count
    }
    
    var upcomingWorkOrders: [DashboardWorkOrder] {
        let activeOrders = workOrders.filter { $0.status.isStartable }
        return activeOrders.map { order in
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
    }
}

struct DashboardWorkOrder: Identifiable {
    var id: UUID { workOrder.id }
    let workOrder: WorkOrder
    let vehicle: Vehicle?
}

private extension JobStatus {
    var isStartable: Bool {
        self == .pending || self == .assigned
    }
}

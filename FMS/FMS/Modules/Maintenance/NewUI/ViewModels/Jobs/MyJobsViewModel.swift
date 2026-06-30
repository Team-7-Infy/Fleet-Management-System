import Foundation
import Combine

final class MyJobsViewModel: ObservableObject {
    @Published private(set) var onHoldOrders: [OnHoldWorkOrder] = []
    @Published var searchText = ""
    @Published private(set) var state: LoadableState<Void> = .idle

    private let workOrderService: any WorkOrderServicing
    private let vehicleService: any VehicleServicing
    private let authService: any AuthServicing
    private var cancellables = Set<AnyCancellable>()

    var filteredOrders: [OnHoldWorkOrder] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else {
            return onHoldOrders
        }

        return onHoldOrders.filter { item in
            let vehicleName = item.vehicle?.name ?? item.workOrder.vehicleName
            return item.workOrder.id.uuidString.localizedCaseInsensitiveContains(trimmedSearch)
                || item.workOrder.title.localizedCaseInsensitiveContains(trimmedSearch)
                || vehicleName.localizedCaseInsensitiveContains(trimmedSearch)
        }
    }

    init(dependencies: AppDependencyContainer) {
        workOrderService = dependencies.workOrderService
        vehicleService = dependencies.vehicleService
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

    func load(isRefresh: Bool = false) async {
        if !isRefresh { state = .loading }
        do {
            let user = try? await authService.currentUser()
            let allAssigned = try await workOrderService.assignedWorkOrders()
            let vehicles = try await vehicleService.vehiclesNeedingAttention()
            
            // Only keep paused/in progress jobs for the current user
            let myOrders = allAssigned.filter { $0.executedBy == user?.personnelId }
            let pausedOrders = myOrders.filter { $0.status == .inProgress }
            
            onHoldOrders = pausedOrders.map { order in
                let vehicleID = order.taskVehicles?.first?.vin
                let vehicle = vehicles.first { $0.id == vehicleID }
                return OnHoldWorkOrder(workOrder: order, vehicle: vehicle)
            }
            
            state = .loaded(())
        } catch let error as AppError {
            state = .failed(error)
        } catch {
            state = .failed(.unknown(error.localizedDescription))
        }
    }
}

struct OnHoldWorkOrder: Identifiable {
    var id: UUID { workOrder.id }
    let workOrder: WorkOrder
    let vehicle: Vehicle?
}

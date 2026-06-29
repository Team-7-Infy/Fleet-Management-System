import Foundation
import Combine

final class JobSummaryViewModel: ObservableObject {
    @Published private(set) var workOrder: WorkOrder?
    @Published private(set) var state: LoadableState<Void> = .idle

    private let workOrderID: WorkOrder.ID
    private let workOrderService: any WorkOrderServicing

    init(workOrderID: WorkOrder.ID, dependencies: AppDependencyContainer) {
        self.workOrderID = workOrderID
        workOrderService = dependencies.workOrderService
    }

    func load() async {
        state = .loading
        do {
            workOrder = try await workOrderService.workOrder(id: workOrderID)
            state = .loaded(())
        } catch let error as AppError {
            state = .failed(error)
        } catch {
            state = .failed(.unknown(error.localizedDescription))
        }
    }
}

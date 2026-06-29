import Foundation
import Combine

final class WorkOrderSuccessViewModel: ObservableObject {
    @Published private(set) var workOrder: WorkOrder?
    @Published private(set) var state: LoadableState<Void> = .idle

    private let workOrderID: WorkOrder.ID
    private let workOrderService: any WorkOrderServicing
    
    private let elapsedTime: TimeInterval
    private let parts: [PartItem]
    private let laborCost: Decimal

    init(workOrderID: WorkOrder.ID, elapsedTime: TimeInterval, parts: [PartItem], laborCost: Decimal, dependencies: AppDependencyContainer) {
        self.workOrderID = workOrderID
        self.elapsedTime = elapsedTime
        self.parts = parts
        self.laborCost = laborCost
        self.workOrderService = dependencies.workOrderService
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

    var formattedLaborTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var formattedTotalCost: String {
        let partsCost = parts.reduce(Decimal(0)) { $0 + ($1.unitPrice * Decimal($1.quantity)) }
        let total = laborCost + partsCost
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return "₹\(formatter.string(from: NSDecimalNumber(decimal: total)) ?? "0")"
    }
    
    var usedParts: [PartItem] {
        return parts
    }
}

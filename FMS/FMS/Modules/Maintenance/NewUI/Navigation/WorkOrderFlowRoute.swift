import Foundation

enum WorkOrderFlowRoute: Hashable {
    case details(WorkOrder.ID)
    case inspectionChecklist(WorkOrder.ID)
    case addPartsReview(WorkOrder.ID)
    case completion(WorkOrder.ID)
    case success(WorkOrder.ID)
}

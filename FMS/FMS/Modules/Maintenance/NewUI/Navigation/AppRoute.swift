import Foundation

enum AppRoute: Hashable {
    case activityHistory
    case jobSummary(workOrderID: WorkOrder.ID)
    case completeWorkOrder(workOrderID: WorkOrder.ID)
    case workOrderSuccess(workOrderID: WorkOrder.ID, elapsedTime: TimeInterval, parts: [PartItem], laborCost: Decimal)
    case upcomingMaintenanceList
    case vehicleDetails(vehicleID: String)
    case pastWorkOrderDetails(workOrderID: WorkOrder.ID)
}

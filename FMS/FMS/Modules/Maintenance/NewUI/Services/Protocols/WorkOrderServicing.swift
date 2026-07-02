import Foundation

protocol WorkOrderServicing {
    func assignedWorkOrders() async throws -> [WorkOrder]
    func scheduledServices() async throws -> [ServiceRecord]
    func workOrder(id: WorkOrder.ID) async throws -> WorkOrder
    func serviceRecord(id: ServiceRecord.ID) async throws -> ServiceRecord
    func inspectionItems(for workOrderID: WorkOrder.ID) async throws -> [MPInspectionItem]
    func parts(for workOrderID: WorkOrder.ID) async throws -> [Part]
    func updateWorkOrder(id: WorkOrder.ID, status: JobStatus, elapsedTime: TimeInterval, parts: [PartItem], remarks: String?, totalCost: Decimal?) async throws
    func fetchInventory() async throws -> [Part]
}

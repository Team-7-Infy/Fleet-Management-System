import Foundation
import Supabase

class MockWorkOrderService: WorkOrderServicing {
    private var internalWorkOrders: [WorkOrder] = PreviewData.workOrders
    
    func assignedWorkOrders() async throws -> [WorkOrder] {
        internalWorkOrders
    }

    func scheduledServices() async throws -> [ServiceRecord] {
        PreviewData.services
    }

    func workOrder(id: WorkOrder.ID) async throws -> WorkOrder {
        guard let workOrder = internalWorkOrders.first(where: { $0.id == id }) else {
            throw AppError.notFound("Work order")
        }
        return workOrder
    }
    
    func updateWorkOrder(id: WorkOrder.ID, status: JobStatus, elapsedTime: TimeInterval, parts: [PartItem], remarks: String?, totalCost: Decimal?, labourCost: Decimal?) async throws {
        // Mock update logic simplified for compilation
    }
    
    func reportInvalidWorkOrder(id: WorkOrder.ID, reason: String, photos: [Data]) async throws {
        // Mock report logic
    }

    func serviceRecord(id: ServiceRecord.ID) async throws -> ServiceRecord {
        guard let service = PreviewData.services.first(where: { $0.id == id }) else {
            throw AppError.notFound("Service")
        }
        return service
    }

    func inspectionItems(for workOrderID: WorkOrder.ID) async throws -> [MPInspectionItem] {
        PreviewData.inspectionItems
    }

    func parts(for workOrderID: WorkOrder.ID) async throws -> [Part] {
        PreviewData.parts
    }

    func fetchInventory() async throws -> [Part] {
        PreviewData.parts
    }
    
    func fetchPersonnelHourlyRate(id: UUID) async throws -> Double {
        450.00
    }
}

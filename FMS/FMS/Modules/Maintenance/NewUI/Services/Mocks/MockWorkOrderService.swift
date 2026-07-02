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
    
    func updateWorkOrder(id: WorkOrder.ID, status: JobStatus, elapsedTime: TimeInterval, parts: [PartItem], remarks: String?, totalCost: Decimal?) async throws {
        // Mock update logic simplified for compilation
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
}

final class SupabaseWorkOrderService: WorkOrderServicing {
    private let apiClient: APIClient
    private let client: SupabaseClient
    
    init(apiClient: APIClient = APIClient(), client: SupabaseClient) {
        self.apiClient = apiClient
        self.client = client
    }
    
    func assignedWorkOrders() async throws -> [WorkOrder] {
        let tasks: [WorkOrder] = try await client
            .from("maintenance_task")
            .select("*,task_vehicles(vin)")
            .execute()
            .value
        return tasks
    }
    
    func scheduledServices() async throws -> [ServiceRecord] {
        let records: [ServiceRecord] = try await client
            .from("maintenance_schedules")
            .select()
            .execute()
            .value
        return records
    }
    
    func workOrder(id: WorkOrder.ID) async throws -> WorkOrder {
        let tasks: [WorkOrder] = try await client
            .from("maintenance_task")
            .select("*,task_vehicles(vin),maintenance_task_parts(quantity,unit_price,inventory(partid,partname))")
            .eq("taskid", value: id.uuidString)
            .execute()
            .value
        guard let task = tasks.first else { throw AppError.notFound("Task") }
        return task
    }
    
    func updateWorkOrder(id: WorkOrder.ID, status: JobStatus, elapsedTime: TimeInterval, parts: [PartItem], remarks: String?, totalCost: Decimal?) async throws {
        // Delete any existing parts for the task
        try await deleteParts(for: id)
        
        // Patch the work order status and elapsed time
        var update: [String: AnyJSON] = [
            "status": .string(status.rawValue),
            "elapsed_time": .integer(Int(elapsedTime))
        ]
        if let remarks = remarks, !remarks.isEmpty {
            update["remarks"] = .string(remarks)
        }
        if let totalCost = totalCost {
            update["totalcost"] = .double(NSDecimalNumber(decimal: totalCost).doubleValue)
        }
        if status == .completed {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            update["completedat"] = .string(isoFormatter.string(from: Date()))
        }
        try await client
            .from("maintenance_task")
            .update(update)
            .eq("taskid", value: id.uuidString)
            .execute()
        
        // Insert new parts if there are any
        if !parts.isEmpty {
            try await insertParts(parts, for: id)
        }
        
        // When completed, reset the vehicle status to active
        if status == .completed {
            try await markVehicleActive(for: id)
        }
    }
    
    private func deleteParts(for taskID: UUID) async throws {
        try await client
            .from("maintenance_task_parts")
            .delete()
            .eq("taskid", value: taskID.uuidString)
            .execute()
    }
    
    private struct TaskPartInsert: Encodable {
        let taskid: String
        let partid: String
        let quantity: Int
        let unit_price: Double
    }

    private func insertParts(_ parts: [PartItem], for taskID: UUID) async throws {
        let partsPayload = parts.map { part in
            TaskPartInsert(
                taskid: taskID.uuidString,
                partid: part.id,
                quantity: part.quantity,
                unit_price: NSDecimalNumber(decimal: part.unitPrice).doubleValue
            )
        }
        
        try await client
            .from("maintenance_task_parts")
            .insert(partsPayload)
            .execute()
        
        for part in parts {
            let params: [String: AnyJSON] = [
                "p_partid": .string(part.id),
                "p_quantity": .integer(part.quantity)
            ]
            try await client.rpc("consume_inventory", params: params).execute()
        }
    }
    
    func serviceRecord(id: ServiceRecord.ID) async throws -> ServiceRecord {
        let records: [ServiceRecord] = try await client
            .from("maintenance_schedules")
            .select()
            .eq("scheduleid", value: id.uuidString)
            .execute()
            .value
        guard let record = records.first else { throw AppError.notFound("Schedule") }
        return record
    }
    
    func inspectionItems(for workOrderID: WorkOrder.ID) async throws -> [MPInspectionItem] {
        return []
    }
    
    func parts(for workOrderID: WorkOrder.ID) async throws -> [Part] {
        let parts: [Part] = try await client
            .from("inventory")
            .select()
            .execute()
            .value
        return parts
    }

    func fetchInventory() async throws -> [Part] {
        let parts: [Part] = try await client
            .from("inventory")
            .select()
            .execute()
            .value
        return parts
    }
    
    private func markVehicleActive(for taskID: UUID) async throws {
        let taskVehicles: [TaskVehicle] = try await client
            .from("task_vehicles")
            .select()
            .eq("taskid", value: taskID.uuidString)
            .execute()
            .value
        for tv in taskVehicles {
            try await client
                .from("vehicles")
                .update(["status": AnyJSON.string("active")])
                .eq("vin", value: tv.vin.uuidString)
                .execute()
        }
    }
}

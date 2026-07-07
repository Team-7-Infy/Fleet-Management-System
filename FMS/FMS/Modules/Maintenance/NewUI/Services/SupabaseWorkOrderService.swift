import Foundation
import Supabase

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
            .select("*,task_vehicles(vin),fleet_manager!maintenance_task_scheduledby_fkey(users(f_name,l_name))")
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
            .select("*,task_vehicles(vin),maintenance_task_parts(quantity,unit_price,inventory(partid,partname)),fleet_manager!maintenance_task_scheduledby_fkey(users(f_name,l_name))")
            .eq("taskid", value: id.uuidString)
            .execute()
            .value
        guard let task = tasks.first else { throw AppError.notFound("Task") }
        return task
    }
    
    func updateWorkOrder(id: WorkOrder.ID, status: JobStatus, elapsedTime: TimeInterval, parts: [PartItem], remarks: String?, totalCost: Decimal?, labourCost: Decimal?) async throws {
        try await deleteParts(for: id)
        
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
        if let labourCost = labourCost {
            update["labour_cost"] = .double(NSDecimalNumber(decimal: labourCost).doubleValue)
        }
        if status == .completed {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            update["completedat"] = .string(isoFormatter.string(from: Date()))
        } else if status == .onHold {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            update["on_hold_reason"] = .string(remarks ?? "On hold")
            update["on_hold_at"] = .string(isoFormatter.string(from: Date()))
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
    
    func reportInvalidWorkOrder(id: WorkOrder.ID, reason: String, photos: [Data]) async throws {
        var uploadedUrls: [String] = []
        
        // 1. Upload photos to Storage
        if !photos.isEmpty {
            for (index, photoData) in photos.enumerated() {
                let fileName = "\(id.uuidString)_report_\(Date().timeIntervalSince1970)_\(index).jpg"
                let filePath = "\(fileName)"
                
                // Note: Assumes a bucket named "work_order_reports" exists and is public
                try await client.storage
                    .from("work_order_reports")
                    .upload(
                        path: filePath,
                        file: photoData,
                        options: FileOptions(contentType: "image/jpeg")
                    )
                
                let publicUrl = try client.storage
                    .from("work_order_reports")
                    .getPublicURL(path: filePath)
                
                uploadedUrls.append(publicUrl.absoluteString)
            }
        }
        
        // 2. Update the maintenance_task
        var update: [String: AnyJSON] = [
            "status": .string(JobStatus.fake.rawValue),
            "remarks": .string(reason)
        ]
        
        if !uploadedUrls.isEmpty {
            // Convert to array of JSON strings
            update["fake_report_photourls"] = .array(uploadedUrls.map { .string($0) })
        }
        
        try await client
            .from("maintenance_task")
            .update(update)
            .eq("taskid", value: id.uuidString)
            .execute()
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
                .update(["status": AnyJSON.string("available")])
                .eq("vin", value: tv.vin.uuidString)
                .execute()
        }
    }
}

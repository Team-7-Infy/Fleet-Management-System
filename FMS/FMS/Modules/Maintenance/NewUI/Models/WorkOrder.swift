import Foundation

struct WorkOrder: Identifiable, Codable, Hashable {
    let id: UUID
    let description: String
    let scheduledDate: String?
    let scheduledBy: UUID?
    let executedBy: UUID?
    let isUrgent: Bool?
    let statusString: String?
    
    // For joining task_vehicles table in Supabase
    let taskVehicles: [MpTaskVehicle]?
    let taskParts: [TaskPartResponse]?
    
    // State Tracking (Local UI state, ignored by Codable if needed or manually ignored)
    var elapsedTime: TimeInterval?
    var usedParts: [PartItem] = []
    
    enum CodingKeys: String, CodingKey {
        case id = "taskid"
        case description
        case scheduledDate = "scheduleddate"
        case scheduledBy = "scheduledby"
        case executedBy = "executedby"
        case isUrgent = "isurgent"
        case statusString = "status"
        case elapsedTime = "elapsed_time"
        case taskVehicles = "task_vehicles"
        case taskParts = "maintenance_task_parts"
    }
    
    // UI Helpers for backward compatibility
    var vehicleID: String { taskVehicles?.first?.vin.uuidString ?? UUID().uuidString }
    var vehicleName: String { taskVehicles?.first?.vin.uuidString.prefix(8).uppercased() ?? "Vehicle" }
    var title: String { description }
    var status: JobStatus { JobStatus(rawValue: statusString ?? "") ?? .pending }
    var priority: Priority { isUrgent == true ? .high : .medium }
    var dueDate: Date {
        if let dateStr = scheduledDate {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoFormatter.date(from: dateStr) { return date }
            
            isoFormatter.formatOptions = [.withInternetDateTime]
            if let date = isoFormatter.date(from: dateStr) { return date }
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let date = formatter.date(from: dateStr) { return date }
        }
        return Date()
    }
    
    var partsCost: Double? { usedParts.reduce(0.0) { $0 + (Double(truncating: $1.unitPrice as NSNumber) * Double($1.quantity)) } }
    
    var mappedParts: [PartItem] {
        taskParts?.compactMap { response in
            guard let inv = response.inventory else { return nil }
            return PartItem(
                id: inv.partid.uuidString,
                name: inv.partname ?? "Unknown Part",
                quantity: response.quantity,
                unitPrice: Decimal(response.unit_price ?? 0)
            )
        } ?? []
    }
}

struct MpTaskVehicle: Codable, Hashable {
    let vin: UUID
}

struct PartItem: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    var quantity: Int
    let unitPrice: Decimal
    
    var amount: Decimal {
        unitPrice * Decimal(quantity)
    }
}

struct TaskPartResponse: Codable, Hashable {
    let quantity: Int
    let unit_price: Double?
    let inventory: InventoryResponse?
    
    struct InventoryResponse: Codable, Hashable {
        let partid: UUID
        let partname: String?
    }
}

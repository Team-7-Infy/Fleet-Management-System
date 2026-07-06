import Foundation

struct WorkOrder: Identifiable, Codable, Hashable {
    let id: UUID
    let taskTitle: String?
    let description: String
    let scheduledDate: String?
    let scheduledBy: UUID?
    let executedBy: UUID?
    let isUrgent: Bool?
    let statusString: String?
    let totalCostDB: Double?
    let photoUrls: [String]?
    let fakeReportPhotoUrls: [String]?
    let remarks: String?
    let completedAt: String?
    
    // For joining task_vehicles table in Supabase
    let taskVehicles: [MpTaskVehicle]?
    let taskParts: [TaskPartResponse]?
    
    // State Tracking (Local UI state, ignored by Codable if needed or manually ignored)
    var elapsedTime: TimeInterval?
    var usedParts: [PartItem] = []
    
    enum CodingKeys: String, CodingKey {
        case id = "taskid"
        case taskTitle = "title"
        case description
        case scheduledDate = "scheduleddate"
        case scheduledBy = "scheduledby"
        case executedBy = "executedby"
        case isUrgent = "isurgent"
        case statusString = "status"
        case totalCostDB = "totalcost"
        case photoUrls = "photourls"
        case fakeReportPhotoUrls = "fake_report_photourls"
        case elapsedTime = "elapsed_time"
        case taskVehicles = "task_vehicles"
        case taskParts = "maintenance_task_parts"
        case remarks
    case completedAt = "completedat"
        case scheduledByRelation = "fleet_manager"
    }
    
    struct FleetManagerRelation: Codable, Hashable {
        let users: UserRelation?
    }
    
    struct UserRelation: Codable, Hashable {
        let f_name: String?
        let l_name: String?
    }
    
    var scheduledByRelation: FleetManagerRelation? = nil
    
    // UI Helpers for backward compatibility
    var vehicleID: String {
        if let vin = taskVehicles?.first?.vin.uuidString {
            return vin
        }
        // Fallback: Parse from description if it contains "(VIN: <UUID>)"
        if let range = description.range(of: "(VIN: ") {
            let start = range.upperBound
            let substring = description[start...]
            if let endRange = substring.range(of: ")") {
                let vinString = String(substring[..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                if UUID(uuidString: vinString) != nil {
                    return vinString
                }
            }
        }
        return UUID().uuidString
    }
    
    var vehicleName: String {
        let id = vehicleID
        return id.prefix(8).uppercased()
    }
    var title: String { taskTitle ?? description }
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
    
    var completedDateFormatted: String {
        guard let dateStr = completedAt else { return "Unknown" }
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date: Date? = isoFormatter.date(from: dateStr)
        
        if date == nil {
            let customFormatter = DateFormatter()
            customFormatter.dateFormat = "yyyy-MM-dd HH:mm:ssX"
            customFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            date = customFormatter.date(from: dateStr)
        }
        
        if date == nil {
            let fallbackFormatter = DateFormatter()
            fallbackFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            fallbackFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            date = fallbackFormatter.date(from: dateStr)
        }
        
        guard let validDate = date else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM HH:mm"
        return formatter.string(from: validDate)
    }
    
    var formattedElapsedTime: String {
        guard let elapsed = elapsedTime else { return "0s" }
        let hours = Int(elapsed) / 3600
        let minutes = (Int(elapsed) % 3600) / 60
        let seconds = Int(elapsed) % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
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

extension WorkOrder {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.taskTitle = try container.decodeIfPresent(String.self, forKey: .taskTitle)
        self.description = try container.decode(String.self, forKey: .description)
        self.scheduledDate = try container.decodeIfPresent(String.self, forKey: .scheduledDate)
        self.scheduledBy = try container.decodeIfPresent(UUID.self, forKey: .scheduledBy)
        self.executedBy = try container.decodeIfPresent(UUID.self, forKey: .executedBy)
        self.isUrgent = try container.decodeIfPresent(Bool.self, forKey: .isUrgent)
        self.statusString = try container.decodeIfPresent(String.self, forKey: .statusString)
        self.totalCostDB = try container.decodeIfPresent(Double.self, forKey: .totalCostDB)
        self.photoUrls = try container.decodeIfPresent([String].self, forKey: .photoUrls)
        self.fakeReportPhotoUrls = try container.decodeIfPresent([String].self, forKey: .fakeReportPhotoUrls)
        self.elapsedTime = try container.decodeIfPresent(TimeInterval.self, forKey: .elapsedTime)
        self.remarks = try container.decodeIfPresent(String.self, forKey: .remarks)
        self.completedAt = try container.decodeIfPresent(String.self, forKey: .completedAt)
        self.scheduledByRelation = try container.decodeIfPresent(FleetManagerRelation.self, forKey: .scheduledByRelation)
        
        // Handle taskVehicles robustly
        if let tv = try? container.decodeIfPresent([MpTaskVehicle].self, forKey: .taskVehicles) {
            self.taskVehicles = tv
        } else {
            let anyContainer = try decoder.container(keyedBy: AnyCodingKey.self)
            self.taskVehicles = (try? anyContainer.decodeIfPresent([MpTaskVehicle].self, forKey: AnyCodingKey(stringValue: "taskVehicles"))) ??
                                (try? anyContainer.decodeIfPresent([MpTaskVehicle].self, forKey: AnyCodingKey(stringValue: "task_vehicles")))
        }
        
        // Handle taskParts robustly
        if let tp = try? container.decodeIfPresent([TaskPartResponse].self, forKey: .taskParts) {
            self.taskParts = tp
        } else {
            let anyContainer = try decoder.container(keyedBy: AnyCodingKey.self)
            self.taskParts = (try? anyContainer.decodeIfPresent([TaskPartResponse].self, forKey: AnyCodingKey(stringValue: "taskParts"))) ??
                             (try? anyContainer.decodeIfPresent([TaskPartResponse].self, forKey: AnyCodingKey(stringValue: "maintenance_task_parts"))) ??
                             (try? anyContainer.decodeIfPresent([TaskPartResponse].self, forKey: AnyCodingKey(stringValue: "maintenanceTaskParts")))
        }
    }
}

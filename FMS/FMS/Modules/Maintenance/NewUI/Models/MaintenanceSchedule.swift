import Foundation

struct MaintenanceSchedule: Identifiable, Codable, Hashable {
    let id: UUID
    let vehicleId: UUID
    let taskType: String
    let intervalKm: Int?
    let intervalDays: Int?
    let lastCompletedKm: Int?
    let lastCompletedDate: Date?
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id = "scheduleid"
        case vehicleId = "vehicleid"
        case taskType = "tasktype"
        case intervalKm = "intervalkm"
        case intervalDays = "intervaldays"
        case lastCompletedKm = "lastcompletedkm"
        case lastCompletedDate = "lastcompleteddate"
        case isActive = "isactive"
        case createdAt = "createdat"
        case updatedAt = "updatedat"
    }
    
    // UI Helpers for backward compatibility
    var vehicleID: String { vehicleId.uuidString }
    var title: String { taskType }
}

typealias ServiceRecord = MaintenanceSchedule

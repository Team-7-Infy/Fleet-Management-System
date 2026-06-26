import Foundation

enum UserRole: String, Codable, CaseIterable {
    case fleetManager = "fleet_manager"
    case driver = "driver"
    case maintenancePersonnel = "maintenance_personnel"
}

import Foundation

protocol WorkOrderAssignmentServiceProtocol: AnyObject, Sendable {
    func findBestPersonnel() async throws -> MaintenancePersonnel?
}

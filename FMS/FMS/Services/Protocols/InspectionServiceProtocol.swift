import Foundation

protocol InspectionServiceProtocol: AnyObject, Sendable {
    func fetchInspections(tripId: UUID) async throws -> [VehicleInspection]
    func createInspection(_ inspection: VehicleInspection) async throws -> VehicleInspection
    func createInspectionItem(_ item: InspectionItemDB) async throws
}

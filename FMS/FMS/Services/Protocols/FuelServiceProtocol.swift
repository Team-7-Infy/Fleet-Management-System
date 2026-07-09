import Foundation

protocol FuelServiceProtocol: AnyObject, Sendable {
    func fetchFuelLogs(tripId: UUID) async throws -> [FuelLog]
}

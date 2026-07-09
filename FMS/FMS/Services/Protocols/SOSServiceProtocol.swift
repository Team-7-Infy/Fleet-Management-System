import Foundation

protocol SOSServiceProtocol: AnyObject, Sendable {
    func createEvent(_ event: SOSEvent) async throws -> SOSEvent
    func fetchEvents(driverId: UUID) async throws -> [SOSEvent]
    func fetchPendingEvents() async throws -> [SOSEvent]
    func updateStatus(id: UUID, status: SOSEvent.SOSStatus, resolvedBy: UUID?, notes: String?) async throws
    func subscribeToEvents(for driverId: UUID) -> AsyncStream<SOSEvent>
}

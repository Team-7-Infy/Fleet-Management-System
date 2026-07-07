import Foundation
import MapKit

final class RouteCorridorService {
    let tripService: TripServiceProtocol

    init(tripService: TripServiceProtocol) {
        self.tripService = tripService
    }

    func generateAndPersistWaypoints(from coordinates: [CLLocationCoordinate2D], tripId: UUID) async throws -> [RouteWaypoint] {
        var sampled: [RouteWaypoint] = []
        var lastPoint: CLLocationCoordinate2D?
        var sequence = 1

        for coord in coordinates {
            if let last = lastPoint {
                let dist = CLLocation(latitude: last.latitude, longitude: last.longitude)
                    .distance(from: CLLocation(latitude: coord.latitude, longitude: coord.longitude))
                if dist < 200 { continue }
            }
            sampled.append(RouteWaypoint(
                id: UUID(),
                tripId: tripId,
                latitude: coord.latitude,
                longitude: coord.longitude,
                bufferRadius: 300,
                sequenceOrder: sequence
            ))
            sequence += 1
            lastPoint = coord
        }

        guard !sampled.isEmpty else { return [] }
        return try await tripService.persistRouteWaypoints(sampled)
    }
}

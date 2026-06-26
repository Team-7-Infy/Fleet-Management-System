import Foundation
import Combine

@MainActor
final class TripManagementViewModel: ObservableObject {
    @Published private(set) var trips: [Trip] = []
    @Published var isLoading = false
    @Published var successMessage: String?
    @Published var errorMessage: String?

    private let tripService: TripServiceProtocol
    private let vehicleService: VehicleServiceProtocol

    init(tripService: TripServiceProtocol, vehicleService: VehicleServiceProtocol) {
        self.tripService = tripService
        self.vehicleService = vehicleService
    }

    var activeTrips: [Trip] {
        trips.filter { $0.status != .completed && $0.status != .rejected }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            trips = try await tripService.fetchTrips()
                .sorted { $0.startTime > $1.startTime }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createTrip(form: FleetManagerTripForm) async -> Bool {
        guard form.isValid else {
            errorMessage = "Select a driver, vehicle, and both locations."
            successMessage = nil
            return false
        }

        do {
            let trip = try await tripService.createTrip(form.makeTrip())
            trips.insert(trip, at: 0)

            if let driverId = form.driverId, let vehicleId = form.vehicleId {
                try await vehicleService.assignDriver(vehicleId: vehicleId, driverId: driverId)
            }

            successMessage = "Trip created for \(trip.startLocation)."
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            successMessage = nil
            return false
        }
    }

    func updateStatus(_ trip: Trip, status: TripStatus) async {
        do {
            try await tripService.updateTripStatus(id: trip.id, status: status)

            if status == .completed || status == .rejected {
                try? await vehicleService.unassignDriver(vehicleId: trip.vehicleId)
            }

            if let index = trips.firstIndex(where: { $0.id == trip.id }) {
                trips[index].status = status
            }
            successMessage = "Trip marked \(status.title.lowercased())."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            successMessage = nil
        }
    }

    func delete(_ trip: Trip) async {
        do {
            try await tripService.deleteTrip(id: trip.id)
            trips.removeAll { $0.id == trip.id }
            try? await vehicleService.unassignDriver(vehicleId: trip.vehicleId)
            successMessage = "Trip deleted."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            successMessage = nil
        }
    }

    func trip(for id: UUID?) -> Trip? {
        guard let id else { return nil }
        return trips.first { $0.id == id }
    }
}

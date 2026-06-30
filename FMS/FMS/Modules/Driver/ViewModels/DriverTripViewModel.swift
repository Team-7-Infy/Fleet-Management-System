import Foundation
import Combine

@MainActor
final class DriverTripViewModel: ObservableObject {
    @Published private(set) var trips: [Trip] = []
    @Published private(set) var vehicles: [Vehicle] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let tripService: TripServiceProtocol
    private let vehicleService: VehicleServiceProtocol
    private let driverId: UUID

    init(
        tripService: TripServiceProtocol,
        vehicleService: VehicleServiceProtocol,
        driverId: UUID
    ) {
        self.tripService = tripService
        self.vehicleService = vehicleService
        self.driverId = driverId
    }

    var driverTrips: [Trip] {
        trips.filter { $0.driverId == driverId }
            .sorted { $0.startTime > $1.startTime }
    }

    var hasRejectionPending: Bool {
        driverTrips.contains { $0.status == .rejectionPending }
    }

    var activeTrip: Trip? {
        driverTrips.first { $0.status == .inProgress || $0.status == .accepted }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let fetchedTrips = tripService.fetchTrips()
            async let fetchedVehicles = vehicleService.fetchVehicles()
            let (t, v) = try await (fetchedTrips, fetchedVehicles)
            trips = t
            vehicles = v
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func vehicle(for id: UUID) -> Vehicle? {
        vehicles.first { $0.id == id }
    }

    func acceptTrip(_ trip: Trip) async {
        guard !hasRejectionPending else {
            errorMessage = "Cannot accept while a rejection request is pending review."
            return
        }
        await updateStatus(trip, status: .accepted)
    }

    func rejectTrip(_ trip: Trip, reason: String) async {
        await updateStatus(trip, status: .rejectionPending, rejectionReason: reason)
    }

    func startTrip(_ trip: Trip) async {
        guard !hasRejectionPending else {
            errorMessage = "Cannot start while a rejection request is pending review."
            return
        }
        await updateStatus(trip, status: .inProgress)
    }

    func endTrip(_ trip: Trip) async {
        await updateStatus(trip, status: .completed)
    }

    private func updateStatus(_ trip: Trip, status: TripStatus, rejectionReason: String? = nil) async {
        do {
            if let reason = rejectionReason {
                try await tripService.updateTripStatus(id: trip.id, status: status, rejectionReason: reason)
            } else {
                try await tripService.updateTripStatus(id: trip.id, status: status)
            }
            if let index = trips.firstIndex(where: { $0.id == trip.id }) {
                trips[index].status = status
                trips[index].rejectionReason = rejectionReason
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

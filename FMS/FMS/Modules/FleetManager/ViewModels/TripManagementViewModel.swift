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
    private var successClearTask: Task<Void, Never>?

    init(tripService: TripServiceProtocol, vehicleService: VehicleServiceProtocol) {
        self.tripService = tripService
        self.vehicleService = vehicleService
    }

    var activeTrips: [Trip] {
        trips.filter { $0.status != .completed && $0.status != .rejected && $0.status != .cancelled }
    }

    var rejectionRequests: [Trip] {
        trips.filter { $0.status == .rejectionPending }
            .sorted { $0.startTime > $1.startTime }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            trips = try await tripService.fetchTrips()
                .sorted { $0.startTime > $1.startTime }
            errorMessage = nil
        } catch is CancellationError {
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createTrip(form: FleetManagerTripForm) async -> Bool {
        guard form.isValid else {
            errorMessage = "Enter a pickup location and destination."
            clearSuccessMessage()
            return false
        }

        do {
            let trip = try await tripService.createTrip(form.makeTrip())
            trips.insert(trip, at: 0)

            showSuccessMessage("Pending trip created for \(trip.startLocation).")
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            clearSuccessMessage()
            return false
        }
    }

    func updateStatus(_ trip: Trip, status: TripStatus) async {
        do {
            try await tripService.updateTripStatus(id: trip.id, status: status)

            if (status == .completed || status == .rejected || status == .cancelled),
               let vehicleId = trip.vehicleId {
                try await vehicleService.unassignDriver(vehicleId: vehicleId)
            }

            if let index = trips.firstIndex(where: { $0.id == trip.id }) {
                trips[index].status = status
            }
            showSuccessMessage("Trip marked \(status.title.lowercased()).")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            clearSuccessMessage()
        }
    }

    func approveRejection(for trip: Trip) async {
        await updateStatus(trip, status: .rejected)
    }

    func denyRejection(for trip: Trip) async {
        do {
            try await tripService.updateTripStatus(id: trip.id, status: .scheduled, rejectionReason: nil)
            if let index = trips.firstIndex(where: { $0.id == trip.id }) {
                trips[index].status = .scheduled
                trips[index].rejectionReason = nil
            }
            showSuccessMessage("Rejection denied, trip returned to scheduled.")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            clearSuccessMessage()
        }
    }

    func delete(_ trip: Trip) async {
        do {
            try await tripService.cancelTrip(id: trip.id)
            if let index = trips.firstIndex(where: { $0.id == trip.id }) {
                trips[index].status = .cancelled
            }
            if let vehicleId = trip.vehicleId {
                try await vehicleService.unassignDriver(vehicleId: vehicleId)
            }
            showSuccessMessage("Trip cancelled.")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            clearSuccessMessage()
        }
    }

    func trip(for id: UUID?) -> Trip? {
        guard let id else { return nil }
        return trips.first { $0.id == id }
    }

    func fetchTelemetry(driverId: UUID) async throws -> Telemetry? {
        return try await tripService.fetchTelemetry(driverId: driverId).first
    }

    private func showSuccessMessage(_ message: String) {
        successMessage = message
        successClearTask?.cancel()
        successClearTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard Task.isCancelled == false else { return }
            await MainActor.run {
                guard self?.successMessage == message else { return }
                self?.successMessage = nil
            }
        }
    }

    private func clearSuccessMessage() {
        successClearTask?.cancel()
        successMessage = nil
    }
}

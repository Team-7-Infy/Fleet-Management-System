import Foundation
import Combine

@MainActor
final class VehicleViewModel: ObservableObject {
    @Published private(set) var vehicles: [Vehicle] = []
    @Published var isLoading = false
    @Published var successMessage: String?
    @Published var errorMessage: String?

    private let service: VehicleServiceProtocol

    init(service: VehicleServiceProtocol) {
        self.service = service
    }

    var activeVehicles: [Vehicle] {
        vehicles.filter { $0.status == .active }
    }

    var maintenanceVehicles: [Vehicle] {
        vehicles.filter { $0.status == .maintenance }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            vehicles = try await service.fetchVehicles()
                .filter { $0.isPlaceholderDemoRecord == false }
                .sorted { $0.licencePlate.localizedCaseInsensitiveCompare($1.licencePlate) == .orderedAscending }
            errorMessage = nil
        } catch is CancellationError {
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createVehicle(form: FleetManagerVehicleForm) async -> Bool {
        guard form.isValid else {
            errorMessage = form.validationMessage ?? "Complete vehicle details. VIN must be a valid UUID if supplied."
            successMessage = nil
            return false
        }

        do {
            let vehicle = try await service.createVehicle(form.makeVehicle())
            vehicles.insert(vehicle, at: 0)
            sortVehicles()
            successMessage = "\(vehicle.licencePlate) added."
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            successMessage = nil
            return false
        }
    }

    func updateStatus(_ vehicle: Vehicle, status: VehicleStatus) async {
        var updated = vehicle
        updated.status = status

        do {
            let saved = try await service.updateVehicle(updated)
            replace(saved)
            successMessage = "\(saved.licencePlate) marked \(status.title.lowercased())."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            successMessage = nil
        }
    }

    func assignDriver(vehicleId: UUID, driverId: UUID) async throws {
        try await service.assignDriver(vehicleId: vehicleId, driverId: driverId)
        if let index = vehicles.firstIndex(where: { $0.id == vehicleId }) {
            vehicles[index].driverId = driverId
        }
    }

    func unassignDriver(vehicleId: UUID) async throws {
        try await service.unassignDriver(vehicleId: vehicleId)
        if let index = vehicles.firstIndex(where: { $0.id == vehicleId }) {
            vehicles[index].driverId = nil
        }
    }

    func delete(_ vehicle: Vehicle) async {
        do {
            try await service.deleteVehicle(id: vehicle.id)
            vehicles.removeAll { $0.id == vehicle.id }
            successMessage = "\(vehicle.licencePlate) deleted."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            successMessage = nil
        }
    }

    func vehicle(for id: UUID?) -> Vehicle? {
        guard let id else { return nil }
        return vehicles.first { $0.id == id }
    }

    private func replace(_ vehicle: Vehicle) {
        if let index = vehicles.firstIndex(where: { $0.id == vehicle.id }) {
            vehicles[index] = vehicle
        } else {
            vehicles.append(vehicle)
        }
        sortVehicles()
    }

    private func sortVehicles() {
        vehicles.sort {
            $0.licencePlate.localizedCaseInsensitiveCompare($1.licencePlate) == .orderedAscending
        }
    }
}

private extension Vehicle {
    var isPlaceholderDemoRecord: Bool {
        let normalizedPlate = licencePlate
            .filter { $0.isWhitespace == false }
            .uppercased()
        if ["UK071234", "UK07AJ9125", "UL043456"].contains(normalizedPlate) {
            return true
        }

        let normalizedName = "\(make) \(model)"
            .lowercased()
            .replacingOccurrences(of: "’", with: "'")
        return normalizedName.contains("that's lead")
            || normalizedName.contains("thats lead")
            || normalizedName.contains("saw safe")
            || normalizedName.contains("mercedes abcd")
    }
}

import Foundation
import Combine

@MainActor
final class VehicleViewModel: ObservableObject {
    @Published private(set) var vehicles: [Vehicle] = []
    @Published var isLoading = false
    @Published var successMessage: String?
    @Published var errorMessage: String?
    @Published private(set) var documents: [VehicleDocument] = []
    @Published private(set) var vehicleHealthScores: [(vehicle: Vehicle, score: Int)] = []

    private let service: VehicleServiceProtocol

    init(service: VehicleServiceProtocol) {
        self.service = service
    }

    var activeVehicles: [Vehicle] {
        vehicles.filter { $0.status == .available }
    }

    var maintenanceVehicles: [Vehicle] {
        vehicles.filter { $0.status == .inMaintenance }
    }

    func load(trips: [Trip] = [], tasks: [MaintenanceTask] = [], taskVehicles: [UUID: [TaskVehicle]] = [:]) async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let postTripInspectionsTask = service.fetchPostTripInspections()
            async let fetchedTask = service.fetchVehicles()

            let postTripInspectionTripIds = (try? await postTripInspectionsTask) ?? []
            let fetched = try await fetchedTask
                .filter { $0.isPlaceholderDemoRecord == false }
            
            var syncedVehicles = fetched
            var statusUpdates: [(vehicleId: UUID, status: VehicleStatus)] = []
            for i in 0..<syncedVehicles.count {
                let v = syncedVehicles[i]
                
                let dbStatus: VehicleStatus
                if v.status == .outOfService {
                    dbStatus = .outOfService
                } else {
                    let vehicleTrips = trips.filter { $0.vehicleId == v.id }
                    let hasActiveTrip = vehicleTrips.contains { $0.status == .accepted || $0.status == .inProgress }
                    let hasScheduledTrip = vehicleTrips.contains { $0.status == .scheduled || $0.status == .pending || $0.status == .rejectionPending }
                    let isLinkedToOpenTask = tasks.contains { task in
                        task.status.isOpen &&
                        (taskVehicles[task.id]?.contains { $0.vin == v.id } ?? false)
                    }
                    
                    let completedTrips = vehicleTrips.filter { $0.status == .completed }
                    var hasPendingInspection = false
                    if let mostRecentCompleted = completedTrips.sorted(by: { $0.startTime > $1.startTime }).first {
                        if !postTripInspectionTripIds.contains(mostRecentCompleted.id) {
                            hasPendingInspection = true
                        }
                    }
                    
                    if hasActiveTrip || hasScheduledTrip || hasPendingInspection {
                        dbStatus = .assigned
                    } else if isLinkedToOpenTask {
                        dbStatus = .inMaintenance
                    } else {
                        dbStatus = .available
                    }
                }
                
                if v.status != dbStatus {
                    statusUpdates.append((vehicleId: v.id, status: dbStatus))
                    syncedVehicles[i].status = dbStatus
                }
            }

            if !statusUpdates.isEmpty {
                try? await service.bulkSetVehicleStatuses(updates: statusUpdates)
            }

            vehicles = syncedVehicles.sorted { $0.licencePlate.localizedCaseInsensitiveCompare($1.licencePlate) == .orderedAscending }
            errorMessage = nil
        } catch is CancellationError {
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadVehicleHealthScores() async {
        do {
            let raw = try await service.fetchVehicleHealthScores()
            let lookup = Dictionary(vehicles.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            vehicleHealthScores = raw.compactMap { (vehicleId, score) in
                guard let v = lookup[vehicleId] else { return nil }
                return (v, score)
            }.sorted { $0.score > $1.score }
        } catch {
            print("Failed to load vehicle health scores: \(error)")
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

    func updateVehicle(_ vehicle: Vehicle, form: FleetManagerVehicleForm) async -> Bool {
        guard form.isValid else {
            errorMessage = form.validationMessage ?? "Complete vehicle details."
            successMessage = nil
            return false
        }

        var updated = vehicle
        updated.make = form.make.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.model = form.model.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.year = form.yearValue ?? vehicle.year
        updated.licencePlate = form.normalizedLicencePlate
        updated.status = form.status
        updated.vehicleType = form.vehicleType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        updated.fuelType = form.fuelType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : form.fuelType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        updated.maintenanceKmInterval = Int(form.maintenanceKmInterval.trimmingCharacters(in: .whitespacesAndNewlines))
        updated.maintenanceMonthInterval = Int(form.maintenanceMonthInterval.trimmingCharacters(in: .whitespacesAndNewlines))

        do {
            let saved = try await service.updateVehicle(updated)
            replace(saved)
            successMessage = "\(saved.licencePlate) updated."
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

    // MARK: - Document Management

    func loadDocuments(for vehicleId: UUID) async {
        do {
            documents = try await service.fetchVehicleDocuments(vehicleId: vehicleId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addDocument(vehicleId: UUID, docType: String, docNumber: String, issueDate: Date, expiryDate: Date) async -> Bool {
        do {
            let document = VehicleDocument(
                id: UUID(),
                vehicleId: vehicleId,
                docType: docType,
                docNumber: docNumber,
                issueDate: DateOnly(wrappedValue: issueDate),
                expiryDate: DateOnly(wrappedValue: expiryDate),
                fileUrl: nil,
                deletedAt: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
            let saved = try await service.createVehicleDocument(document)
            documents.append(saved)
            successMessage = "\(docType.capitalized) document added."
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            successMessage = nil
            return false
        }
    }

    func removeDocument(id: UUID) async -> Bool {
        do {
            try await service.deleteVehicleDocument(id: id)
            documents.removeAll { $0.id == id }
            successMessage = "Document removed."
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            successMessage = nil
            return false
        }
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

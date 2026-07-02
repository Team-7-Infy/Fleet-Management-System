import Foundation
import Combine

final class LocalDataStore: ObservableObject {
    static let shared = LocalDataStore()

    @Published var fuelHistory: [FuelRecord] = []
    @Published var incidents: [Incident] = []
    @Published var inspectedVehicles: Set<String> = []
    @Published var isNavigationActive = false

    private let fuelKey = "local_fuel_history"
    private let incidentKey = "local_incidents"

    private init() {
        loadFuelHistory()
        loadIncidents()
    }

    // MARK: - Fuel

    func submitFuelRequest(vehicleId: String, fuelType: FuelRecord.FuelType, amount: Double, currentLevel: Double) {
        let record = FuelRecord(
            id: UUID(),
            date: Date(),
            vehicleId: vehicleId,
            tripId: nil,
            fuelType: fuelType,
            amountRequested: amount,
            currentFuelLevel: currentLevel,
            status: .pending
        )
        fuelHistory.append(record)
        saveFuelHistory()
    }

    func saveFuelEntry(vehicleId: String, tripId: String, fuelType: FuelRecord.FuelType, liters: Double, price: Double, receiptCode: String, date: Date) {
        let record = FuelRecord(
            id: UUID(),
            date: date,
            vehicleId: vehicleId,
            tripId: tripId,
            fuelType: fuelType,
            cost: price,
            volumeFilled: liters,
            pricePerLiter: price / liters,
            currentFuelLevel: 0,
            status: .completed,
            receiptCode: receiptCode
        )
        fuelHistory.append(record)
        saveFuelHistory()
    }

    func fuelRecords(for tripId: String) -> [FuelRecord] {
        fuelHistory.filter { $0.tripId == tripId }
    }

    private func saveFuelHistory() {
        if let data = try? JSONEncoder().encode(fuelHistory) {
            UserDefaults.standard.set(data, forKey: fuelKey)
        }
    }

    private func loadFuelHistory() {
        guard let data = UserDefaults.standard.data(forKey: fuelKey),
              let records = try? JSONDecoder().decode([FuelRecord].self, from: data) else { return }
        fuelHistory = records
    }

    // MARK: - Incidents

    func submitIncident(type: Incident.IncidentType, description: String, photos: [String], latitude: Double?, longitude: Double?, tripId: String?) {
        let incident = Incident(
            id: UUID(),
            date: Date(),
            type: type,
            description: description,
            latitude: latitude,
            longitude: longitude,
            photoURLs: photos,
            status: .submitted,
            tripId: tripId
        )
        incidents.append(incident)
        saveIncidents()
    }

    func incidents(for tripId: String) -> [Incident] {
        incidents.filter { $0.tripId == tripId }
    }

    private func saveIncidents() {
        if let data = try? JSONEncoder().encode(incidents) {
            UserDefaults.standard.set(data, forKey: incidentKey)
        }
    }

    private func loadIncidents() {
        guard let data = UserDefaults.standard.data(forKey: incidentKey),
              let items = try? JSONDecoder().decode([Incident].self, from: data) else { return }
        incidents = items
    }

    // MARK: - Inspection

    func markTripInspected(_ tripId: String) {
        inspectedVehicles.insert(tripId)
    }

    func isTripInspected(_ tripId: String) -> Bool {
        inspectedVehicles.contains(tripId)
    }

    // MARK: - Navigation

    func startNavigation() {
        isNavigationActive = true
    }

    func endNavigation() {
        isNavigationActive = false
    }
}

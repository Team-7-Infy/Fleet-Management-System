import Foundation
import Combine
import Supabase

struct PendingPostTripInspection: Codable {
    let tripId: String
    let deadline: Date
}

final class LocalDataStore: ObservableObject {
    static let shared = LocalDataStore()

    var supabase: SupabaseClient?
    var currentDriverId: UUID?

    @Published var fuelHistory: [FuelRecord] = []
    @Published var lastFuelSaveError: String? = nil
    @Published var incidents: [Incident] = []
    @Published var inspectedVehicles: Set<String> = []
    @Published var isNavigationActive = false
    @Published var pendingPostTripInspection: PendingPostTripInspection? {
        didSet {
            if let data = try? JSONEncoder().encode(pendingPostTripInspection) {
                UserDefaults.standard.set(data, forKey: "pending_post_trip_inspection")
            } else {
                UserDefaults.standard.removeObject(forKey: "pending_post_trip_inspection")
            }
        }
    }

    var hasPendingPostTripInspection: Bool {
        pendingPostTripInspection != nil
    }

    var isPostTripInspectionOverdue: Bool {
        guard let pending = pendingPostTripInspection else { return false }
        return Date() >= pending.deadline
    }

    private let fuelKey = "local_fuel_history"
    private let incidentKey = "local_incidents"

    private init() {
        loadFuelHistory()
        loadIncidents()
        if let data = UserDefaults.standard.data(forKey: "pending_post_trip_inspection"),
           let pending = try? JSONDecoder().decode(PendingPostTripInspection.self, from: data) {
            pendingPostTripInspection = pending
        }
    }

    func configure(supabase: SupabaseClient) {
        self.supabase = supabase
    }

    // MARK: - Fuel

    func submitFuelRequest(vehicleId: String, fuelType: FuelRecord.FuelType, amount: Double, currentLevel: Double) async {
        guard let driverId = currentDriverId else {
            await MainActor.run { self.lastFuelSaveError = "Driver profile not loaded yet. Please try again in a moment." }
            return
        }

        let record = FuelRecord(
            id: UUID(),
            date: Date(),
            vehicleId: vehicleId,
            tripId: nil,
            fuelType: fuelType,
            amountRequested: amount,
            currentFuelLevel: currentLevel
        )

        guard let client = supabase else {
            await MainActor.run {
                self.lastFuelSaveError = "Not connected — entry saved locally only."
                self.fuelHistory.append(record)
                self.saveFuelHistory()
            }
            return
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
        var payload: [String: AnyJSON] = [
            "id": .string(record.id.uuidString),
            "date": .string(formatter.string(from: record.date)),
            "vehicle_id": .string(record.vehicleId),
            "fuel_type": .string(record.fuelType.rawValue),
            "amount_requested": .double(amount),
            "current_fuel_level": .double(currentLevel),
            "driver_id": .string(driverId.uuidString),
        ]
        if let tripId = record.tripId {
            payload["trip_id"] = .string(tripId)
        }

        do {
            try await client.from("fuel_logs").insert(payload).execute()
            await MainActor.run {
                self.fuelHistory.append(record)
                self.saveFuelHistory()
                self.lastFuelSaveError = nil
            }
        } catch {
            await MainActor.run {
                self.lastFuelSaveError = "Failed to save fuel entry: \(error.localizedDescription)"
            }
        }
    }

    func saveFuelEntry(vehicleId: UUID, tripId: String, fuelType: FuelRecord.FuelType, liters: Double, price: Double, receiptCode: String, date: Date) async {
        guard let driverId = currentDriverId else {
            await MainActor.run { self.lastFuelSaveError = "Driver profile not loaded yet. Please try again in a moment." }
            return
        }

        let record = FuelRecord(
            id: UUID(),
            date: date,
            vehicleId: vehicleId.uuidString,
            tripId: tripId,
            fuelType: fuelType,
            cost: price,
            volumeFilled: liters,
            pricePerLiter: price / liters,
            currentFuelLevel: 0,
            receiptCode: receiptCode
        )

        guard let client = supabase else {
            await MainActor.run {
                self.lastFuelSaveError = "Not connected — entry saved locally only."
                self.fuelHistory.append(record)
                self.saveFuelHistory()
            }
            return
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
        var payload: [String: AnyJSON] = [
            "id": .string(record.id.uuidString),
            "date": .string(formatter.string(from: record.date)),
            "vehicle_id": .string(record.vehicleId),
            "trip_id": .string(tripId),
            "fuel_type": .string(record.fuelType.rawValue),
            "cost": .double(price),
            "volume_filled": .double(liters),
            "price_per_liter": .double(price / liters),
            "current_fuel_level": .double(0),
            "driver_id": .string(driverId.uuidString),
        ]
        if let code = record.receiptCode {
            payload["receipt_code"] = .string(code)
        }

        do {
            try await client.from("fuel_logs").insert(payload).execute()
            await MainActor.run {
                self.fuelHistory.append(record)
                self.saveFuelHistory()
                self.lastFuelSaveError = nil
            }
        } catch {
            await MainActor.run {
                self.lastFuelSaveError = "Failed to save fuel entry: \(error.localizedDescription)"
            }
        }
    }

    func loadFuelHistoryFromDatabase(driverId: UUID) async {
        guard let client = supabase else { return }
        do {
            let rawResponse: AnyJSON = try await client
                .from("fuel_logs")
                .select()
                .eq("driver_id", value: driverId.uuidString)
                .order("date", ascending: false)
                .execute()
                .value

            guard let jsonData = try? JSONSerialization.data(withJSONObject: rawResponse.value),
                  let array = try JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else { return }

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
            let records: [FuelRecord] = array.compactMap { dict in
                guard let idString = dict["id"] as? String,
                      let id = UUID(uuidString: idString),
                      let dateString = dict["date"] as? String,
                      let date = formatter.date(from: dateString) ?? ({ let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withColonSeparatorInTimeZone]; return f.date(from: dateString) }()),
                      let vehicleId = dict["vehicle_id"] as? String,
                      let fuelTypeRaw = dict["fuel_type"] as? String,
                      let fuelType = FuelRecord.FuelType(rawValue: fuelTypeRaw),
                      let currentFuelLevel = dict["current_fuel_level"] as? Double else { return nil }

                let tripId = dict["trip_id"] as? String
                let amountRequested = dict["amount_requested"] as? Double
                let cost = dict["cost"] as? Double
                let volumeFilled = dict["volume_filled"] as? Double
                let pricePerLiter = dict["price_per_liter"] as? Double
                let receiptCode = dict["receipt_code"] as? String
                let receiptImageURL = dict["receipt_image_url"] as? String
                let kWhAdded = dict["kWh_added"] as? Double
                let chargePercentBefore = dict["charge_percent_before"] as? Double
                let chargePercentAfter = dict["charge_percent_after"] as? Double

                return FuelRecord(
                    id: id, date: date, vehicleId: vehicleId,
                    tripId: tripId, fuelType: fuelType,
                    amountRequested: amountRequested, cost: cost,
                    volumeFilled: volumeFilled, pricePerLiter: pricePerLiter,
                    currentFuelLevel: currentFuelLevel,
                    receiptCode: receiptCode, receiptImageURL: receiptImageURL,
                    kWhAdded: kWhAdded, chargePercentBefore: chargePercentBefore,
                    chargePercentAfter: chargePercentAfter
                )
            }

            await MainActor.run {
                fuelHistory = records
                saveFuelHistory()
            }
        } catch {
            print("Failed to load fuel history: \(error)")
        }
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

    func markTripInspected(_ tripId: String, vehicleId: UUID? = nil) {
        let tid = tripId.lowercased()
        if let vehicleId {
            inspectedVehicles.insert("\(tid)-\(vehicleId.uuidString.lowercased())")
        } else {
            inspectedVehicles.insert(tid)
        }
    }

    func isTripInspected(_ tripId: String, vehicleId: UUID? = nil) -> Bool {
        let tid = tripId.lowercased()
        if let vehicleId {
            return inspectedVehicles.contains("\(tid)-\(vehicleId.uuidString.lowercased())")
        }
        return inspectedVehicles.contains(tid)
    }

    func unmarkTripInspected(_ tripId: String) {
        let tid = tripId.lowercased()
        inspectedVehicles.remove(tid)
        inspectedVehicles = inspectedVehicles.filter { !$0.hasPrefix("\(tid)-") }
    }

    // MARK: - Navigation

    func startNavigation() {
        isNavigationActive = true
    }

    func endNavigation() {
        isNavigationActive = false
    }
}

import Foundation
import Supabase



final actor VehicleService: VehicleServiceProtocol {
    private let supabase: SupabaseServiceProtocol

    init(supabase: SupabaseServiceProtocol) {
        self.supabase = supabase
    }

    func fetchVehicles() async throws -> [Vehicle] {
        try await supabase.client
            .from("vehicles")
            .select()
            .is("deleted_at", value: nil)
            .execute()
            .value
    }

    func fetchVehicles(forDriverId driverId: UUID) async throws -> [Vehicle] {
        try await supabase.client
            .from("vehicles")
            .select()
            .eq("driverid", value: driverId.uuidString)
            .is("deleted_at", value: nil)
            .execute()
            .value
    }

    func fetchVehicle(id: UUID) async throws -> Vehicle {
        try await supabase.client
            .from("vehicles")
            .select()
            .eq("vin", value: id.uuidString)
            .is("deleted_at", value: nil)
            .single()
            .execute()
            .value
    }

    func createVehicle(_ vehicle: Vehicle) async throws -> Vehicle {
        try await supabase.client
            .from("vehicles")
            .insert(vehicle, returning: .representation)
            .select()
            .single()
            .execute()
            .value
    }

    func updateVehicle(_ vehicle: Vehicle) async throws -> Vehicle {
        try await supabase.client
            .from("vehicles")
            .update(vehicle, returning: .representation)
            .eq("vin", value: vehicle.id.uuidString)
            .select()
            .single()
            .execute()
            .value
    }

    func deleteVehicle(id: UUID) async throws {
        try await supabase.client
            .from("vehicles")
            .update(["deleted_at": AnyJSON.string(ISO8601DateFormatter().string(from: Date()))])
            .eq("vin", value: id.uuidString)
            .execute()
    }

    func setOutOfService(vehicleId: UUID) async throws {
        try await supabase.client
            .from("vehicles")
            .update(["status": AnyJSON.string(VehicleStatus.outOfService.rawValue)])
            .eq("vin", value: vehicleId.uuidString)
            .execute()
    }

    func setVehicleStatus(vehicleId: UUID, status: VehicleStatus) async throws {
        try await supabase.client
            .from("vehicles")
            .update(["status": AnyJSON.string(status.rawValue)])
            .eq("vin", value: vehicleId.uuidString)
            .execute()
    }

    func fetchVehicleDocuments(vehicleId: UUID) async throws -> [VehicleDocument] {
        try await supabase.client
            .from("vehicle_documents")
            .select()
            .eq("vehicle_id", value: vehicleId.uuidString)
            .is("deleted_at", value: nil)
            .execute()
            .value
    }

    func createVehicleDocument(_ document: VehicleDocument) async throws -> VehicleDocument {
        try await supabase.client
            .from("vehicle_documents")
            .insert(document, returning: .representation)
            .select()
            .single()
            .execute()
            .value
    }

    func updateVehicleDocument(_ document: VehicleDocument) async throws -> VehicleDocument {
        try await supabase.client
            .from("vehicle_documents")
            .update(document, returning: .representation)
            .eq("id", value: document.id.uuidString)
            .select()
            .single()
            .execute()
            .value
    }

    func deleteVehicleDocument(id: UUID) async throws {
        try await supabase.client
            .from("vehicle_documents")
            .update(["deleted_at": AnyJSON.string(ISO8601DateFormatter().string(from: Date()))])
            .eq("id", value: id.uuidString)
            .execute()
    }

    func assignDriver(vehicleId: UUID, driverId: UUID) async throws {
        try await supabase.client
            .from("vehicles")
            .update(["driverid": driverId.uuidString])
            .eq("vin", value: vehicleId.uuidString)
            .execute()
    }

    func unassignDriver(vehicleId: UUID) async throws {
        let params: [String: AnyJSON] = ["driverid": .null]
        try await supabase.client
            .from("vehicles")
            .update(params)
            .eq("vin", value: vehicleId.uuidString)
            .execute()
    }

    func fetchVehicleHealthScores() async throws -> [(vehicleId: UUID, score: Int)] {
        struct CachedScore: Codable {
            let vehicleId: UUID
            let score: Int
            let calculatedAt: Date
            
            enum CodingKeys: String, CodingKey {
                case vehicleId = "vehicle_id"
                case score
                case calculatedAt = "calculated_at"
            }
        }
        
        let now = Date()
        
        // 1. Fetch active vehicles first to verify coverage
        let vehicles: [Vehicle] = try await supabase.client
            .from("vehicles")
            .select()
            .is("deleted_at", value: nil)
            .execute()
            .value
            
        // 2. Fetch cached health scores
        let cached: [CachedScore] = (try? await supabase.client
            .from("vehicle_health_scores")
            .select()
            .execute()
            .value) ?? []
            
        let cachedLookup = Dictionary(uniqueKeysWithValues: cached.map { ($0.vehicleId, $0) })
        
        // Verify all vehicles are cached and fresh (within 24 hours)
        let allFresh = !vehicles.isEmpty && vehicles.allSatisfy { vehicle in
            if let entry = cachedLookup[vehicle.id] {
                return now.timeIntervalSince(entry.calculatedAt) < 24 * 3600
            }
            return false
        }
        
        if allFresh {
            let cachedResults: [(vehicleId: UUID, score: Int)] = vehicles.map { vehicle in
                (vehicleId: vehicle.id, score: cachedLookup[vehicle.id]?.score ?? 100)
            }
            return cachedResults.sorted(by: { $0.score > $1.score })
        }
        
        // 3. Fallback to recalculating and caching (upserting)
        let allTasks: [MaintenanceTask] = try await supabase.client
            .from("maintenance_task")
            .select()
            .execute()
            .value

        let allTaskVehicles: [TaskVehicle] = try await supabase.client
            .from("task_vehicles")
            .select()
            .execute()
            .value

        let vehiclesWithTasks: [UUID: [MaintenanceTask]] = {
            var map: [UUID: [MaintenanceTask]] = [:]
            for tv in allTaskVehicles {
                let task = allTasks.first { $0.id == tv.taskId }
                if let task {
                    map[tv.vin, default: []].append(task)
                }
            }
            return map
        }()

        let allInspections: [VehicleInspection] = try await supabase.client
            .from("vehicle_inspections")
            .select()
            .execute()
            .value

        let vehiclesWithInspections = Dictionary(grouping: allInspections) { $0.vehicleId }

        let fuelEntries: [ExpenseEntry] = try await supabase.client
            .from("expense_entries")
            .select()
            .eq("expense_type", value: "fuel")
            .execute()
            .value

        let fuelByVehicle = Dictionary(grouping: fuelEntries) { $0.vehicleId }

        let allTrips: [Trip] = try await supabase.client
            .from("trips")
            .select()
            .eq("status", value: "completed")
            .execute()
            .value

        let tripsByVehicle = Dictionary(grouping: allTrips) { $0.vehicleId }

        var results: [(vehicleId: UUID, score: Int)] = []
        for vehicle in vehicles {
            let vehicleTasks = vehiclesWithTasks[vehicle.id] ?? []

            // Factor 1: Fleet Tenure / Age
            let fleetAge: Double
            if let added = vehicle.addedToFleetAt {
                fleetAge = Calendar.current.dateComponents([.year], from: added, to: Date()).year.map(Double.init) ?? 0
            } else {
                fleetAge = Double(max(0, Calendar.current.component(.year, from: Date()) - vehicle.year))
            }
            let ageScore: Double
            if fleetAge <= 2 { ageScore = 100 }
            else if fleetAge <= 5 { ageScore = 80 }
            else if fleetAge <= 8 { ageScore = 50 }
            else { ageScore = 20 }

            // Factor 2: Fuel Efficiency Trend
            let vehicleFuelEntries = fuelByVehicle[vehicle.id] ?? []
            let vehicleTrips = tripsByVehicle[vehicle.id] ?? []
            let fuelEfficiencyScore: Double
            if !vehicleFuelEntries.isEmpty && !vehicleTrips.isEmpty {
                let totalLiters = vehicleFuelEntries.compactMap(\.liters).reduce(0, +)
                let totalDistance = vehicleTrips.compactMap(\.distanceKm).reduce(0, +)
                if totalDistance > 0 && totalLiters > 0 {
                    let efficiency = totalDistance / totalLiters
                    let expectedEfficiency: Double = vehicle.fuelType == "diesel" ? 12 : vehicle.fuelType == "cng" ? 18 : 14
                    let ratio = min(efficiency / expectedEfficiency, 2.0)
                    fuelEfficiencyScore = min(100, ratio * 50)
                } else {
                    fuelEfficiencyScore = 100
                }
            } else {
                fuelEfficiencyScore = 100
            }

            // Factor 3: Maintenance Adherence
            let completedTasks = vehicleTasks.filter { $0.status == .completed }
            let adherenceScore: Double
            if !vehicleTasks.isEmpty {
                let totalNeeded = vehicleTasks.count
                let completed = completedTasks.count
                adherenceScore = Double(completed) / Double(totalNeeded) * 100
            } else {
                adherenceScore = 100
            }

            // Factor 4: Defect / Inspection History
            let vehicleInspections = vehiclesWithInspections[vehicle.id] ?? []
            let inspectionScore: Double
            if !vehicleInspections.isEmpty {
                let passed = vehicleInspections.filter { $0.status == .passed }.count
                inspectionScore = Double(passed) / Double(vehicleInspections.count) * 100
            } else {
                inspectionScore = 100
            }

            // Factor 5: Critical Repairs / Maintenance Burden
            let totalCost = completedTasks.compactMap(\.totalCost).reduce(0, +) +
                            completedTasks.compactMap(\.labourCost).reduce(0, +)
            let burdenScore: Double
            if totalCost > 0 {
                let normalized = min(totalCost / 50000, 1.0)
                burdenScore = max(0, (1.0 - normalized) * 100)
            } else {
                burdenScore = 100
            }

            let overall = (ageScore + fuelEfficiencyScore + adherenceScore + inspectionScore + burdenScore) / 5.0
            results.append((vehicle.id, max(0, min(100, Int(overall.rounded())))))
        }

        let cacheToUpsert = results.map { CachedScore(vehicleId: $0.vehicleId, score: $0.score, calculatedAt: now) }
        if !cacheToUpsert.isEmpty {
            try? await supabase.client
                .from("vehicle_health_scores")
                .upsert(cacheToUpsert)
                .execute()
        }

        return results.sorted(by: { $0.score > $1.score })
    }

    func fetchPostTripInspections() async throws -> [UUID] {
        struct InspectionCheck: Codable {
            let trip_id: UUID
        }
        let response: [InspectionCheck] = try await supabase.client
            .from("vehicle_inspections")
            .select("trip_id")
            .eq("type", value: "post_trip")
            .execute()
            .value
        return response.map(\.trip_id)
    }
}

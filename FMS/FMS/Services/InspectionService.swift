import Foundation
import Supabase

final actor InspectionService: InspectionServiceProtocol {
    private let supabase: SupabaseServiceProtocol

    init(supabase: SupabaseServiceProtocol) {
        self.supabase = supabase
    }

    func fetchInspections(tripId: UUID) async throws -> [VehicleInspection] {
        try await supabase.client
            .from("vehicle_inspections")
            .select()
            .eq("trip_id", value: tripId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func createInspection(_ inspection: VehicleInspection) async throws -> VehicleInspection {
        try await supabase.client
            .from("vehicle_inspections")
            .insert(inspection, returning: .representation)
            .select()
            .single()
            .execute()
            .value
    }

    func createInspectionItem(_ item: InspectionItemDB) async throws {
        try await supabase.client
            .from("inspection_items")
            .insert(item)
            .execute()
    }
}

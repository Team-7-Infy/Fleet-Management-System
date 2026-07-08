import Foundation
import Supabase

final actor FuelService: FuelServiceProtocol {
    private let supabase: SupabaseServiceProtocol

    init(supabase: SupabaseServiceProtocol) {
        self.supabase = supabase
    }

    func fetchFuelLogs(tripId: UUID) async throws -> [FuelLog] {
        try await supabase.client
            .from("fuel_logs")
            .select()
            .eq("trip_id", value: tripId.uuidString)
            .order("date", ascending: false)
            .execute()
            .value
    }
}

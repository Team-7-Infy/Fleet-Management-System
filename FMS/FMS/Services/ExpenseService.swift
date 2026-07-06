import Foundation
import Supabase

final actor ExpenseService: ExpenseServiceProtocol {
    private let supabase: SupabaseServiceProtocol

    init(supabase: SupabaseServiceProtocol) {
        self.supabase = supabase
    }

    func fetchExpenses(tripId: UUID?) async throws -> [ExpenseEntry] {
        var query = supabase.client
            .from("expense_entries")
            .select()
        if let tripId {
            query = query.eq("trip_id", value: tripId.uuidString)
        }
        return try await query
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func createExpense(_ entry: ExpenseEntry) async throws -> ExpenseEntry {
        try await supabase.client
            .from("expense_entries")
            .insert(entry, returning: .representation)
            .select()
            .single()
            .execute()
            .value
    }

    func deleteExpense(id: UUID) async throws {
        try await supabase.client
            .from("expense_entries")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}

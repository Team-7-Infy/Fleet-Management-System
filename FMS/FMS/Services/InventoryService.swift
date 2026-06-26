import Foundation
import Supabase



final actor InventoryService: InventoryServiceProtocol {
    private let supabase: SupabaseServiceProtocol

    init(supabase: SupabaseServiceProtocol) {
        self.supabase = supabase
    }

    func fetchParts() async throws -> [InventoryPart] {
        try await supabase.client
            .from("inventory")
            .select()
            .execute()
            .value
    }

    func fetchPart(id: UUID) async throws -> InventoryPart {
        try await supabase.client
            .from("inventory")
            .select()
            .eq("partid", value: id.uuidString)
            .single()
            .execute()
            .value
    }

    func createPart(_ part: InventoryPart) async throws -> InventoryPart {
        try await supabase.client
            .from("inventory")
            .insert(part, returning: .representation)
            .select()
            .single()
            .execute()
            .value
    }

    func updatePart(_ part: InventoryPart) async throws -> InventoryPart {
        try await supabase.client
            .from("inventory")
            .update(part, returning: .representation)
            .eq("partid", value: part.id.uuidString)
            .select()
            .single()
            .execute()
            .value
    }

    func deletePart(id: UUID) async throws {
        try await supabase.client
            .from("inventory")
            .delete()
            .eq("partid", value: id.uuidString)
            .execute()
    }

    func adjustQuantity(id: UUID, delta: Int) async throws {
        let params: [String: AnyJSON] = [
            "part_id": .string(id.uuidString),
            "delta": .integer(delta)
        ]
        try await supabase.client
            .rpc("adjust_inventory_quantity", params: params)
            .execute()
    }
}

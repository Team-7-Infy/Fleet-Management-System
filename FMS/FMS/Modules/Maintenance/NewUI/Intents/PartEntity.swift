import AppIntents
import Foundation

@MainActor
final class PartEntityCache {
    static let shared = PartEntityCache()

    private var allParts: [InventoryItem] = []
    private init() {}

    func update(with parts: [InventoryItem]) {
        allParts = parts
    }

    var isEmpty: Bool { allParts.isEmpty }

    /// Aggregate duplicate parts by name (same name, summed quantity).
    /// Used by the entity query so Siri sees one candidate per distinct part name.
    func aggregatedParts(for vehicleType: String?) -> [InventoryItem] {
        let filtered = vehicleType.map { vt in
            allParts.filter { $0.vehicletype?.lowercased() == vt.lowercased() || $0.vehicletype == nil }
        } ?? allParts

        let grouped = Dictionary(grouping: filtered) { $0.partname ?? "" }
        return grouped.compactMap { name, items in
            guard !name.isEmpty else { return nil }
            let first = items[0]
            return InventoryItem(
                id: first.id,
                partname: name,
                cost: first.cost,
                quantityOnHand: items.reduce(0) { $0 + ($1.quantityOnHand ?? 0) },
                vehicletype: first.vehicletype
            )
        }
    }

    func availableQuantity(for partID: String) -> Int {
        let uuid = UUID(uuidString: partID)
        let matched = allParts.filter { $0.id.uuidString == partID || $0.id == uuid }
        return matched.reduce(0) { $0 + ($1.quantityOnHand ?? 0) }
    }
}

struct PartEntity: AppEntity {
    static var defaultQuery = PartEntityQuery()
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Part"

    let id: String
    let name: String
    let vehicleType: String?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(id: String, name: String, vehicleType: String?) {
        self.id = id
        self.name = name
        self.vehicleType = vehicleType
    }
}

struct PartEntityQuery: EntityStringQuery {
    func entities(matching string: String) async throws -> [PartEntity] {
        let candidates = await fetchAggregatedParts()
        let lowered = string.lowercased()

        let exact = candidates.filter { $0.name.lowercased() == lowered }
        if !exact.isEmpty {
            return exact.map { PartEntity(id: $0.id.uuidString, name: $0.name, vehicleType: $0.vehicletype) }
        }

        let substring = candidates.filter { $0.name.lowercased().contains(lowered) }
        return substring.map { PartEntity(id: $0.id.uuidString, name: $0.name, vehicleType: $0.vehicletype) }
    }

    func suggestedEntities() async throws -> [PartEntity] {
        let candidates = await fetchAggregatedParts()
        return candidates.prefix(20).map { PartEntity(id: $0.id.uuidString, name: $0.name, vehicleType: $0.vehicletype) }
    }

    func entities(for identifiers: [PartEntity.ID]) async throws -> [PartEntity] {
        let candidates = await fetchAggregatedParts()
        return candidates
            .filter { identifiers.contains($0.id.uuidString) }
            .map { PartEntity(id: $0.id.uuidString, name: $0.name, vehicleType: $0.vehicletype) }
    }

    /// Fetch aggregated parts from the cache, on MainActor.
    private func fetchAggregatedParts() async -> [InventoryItem] {
        await MainActor.run {
            PartEntityCache.shared.aggregatedParts(for: VoiceActionBridge.shared.currentVehicleType)
        }
    }
}

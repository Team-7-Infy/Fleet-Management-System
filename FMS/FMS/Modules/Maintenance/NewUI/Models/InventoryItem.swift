import Foundation

struct InventoryItem: Identifiable, Codable, Hashable {
    let id: UUID
    let partname: String?
    let cost: Double?
    let quantityOnHand: Int?
    let vehicletype: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "partid"
        case partname
        case cost
        case quantityOnHand = "quantity"
        case vehicletype
    }
    
    // UI Helpers for backward compatibility
    var name: String { partname ?? "Unknown Part" }
    
    var currentQuantity: Int { quantityOnHand ?? 0 }
    
    var quantity: Int { quantityOnHand ?? 0 }
    var unitPrice: Decimal { Decimal(cost ?? 0) }
}

typealias SparePart = InventoryItem
typealias Part = InventoryItem

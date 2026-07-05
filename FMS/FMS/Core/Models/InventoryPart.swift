import Foundation

struct InventoryPart: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var partName: String
    var cost: Double
    var quantity: Int
    var vehicleType: String
    var sku: String?
    var partDescription: String?
    var category: String?
    var unit: String?
    var reorderLevel: Int?
    var unitCost: Double?
    var threshold: Int

    enum CodingKeys: String, CodingKey {
        case id = "partid"
        case partName = "partname"
        case cost
        case quantity
        case vehicleType = "vehicletype"
        case sku
        case partDescription = "description"
        case category
        case unit
        case reorderLevel = "reorderlevel"
        case unitCost = "unitcost"
        case threshold
    }
}

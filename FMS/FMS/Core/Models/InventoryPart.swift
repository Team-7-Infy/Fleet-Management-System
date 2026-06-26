import Foundation

struct InventoryPart: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var partName: String
    var cost: Double
    var quantity: Int
    var vehicleType: String

    enum CodingKeys: String, CodingKey {
        case id = "partid"
        case partName = "partname"
        case cost
        case quantity
        case vehicleType = "vehicletype"
    }
}

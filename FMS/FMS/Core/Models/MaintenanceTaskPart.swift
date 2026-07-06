import Foundation

struct MaintenanceTaskPart: Codable, Hashable, Sendable {
    let taskId: UUID
    let partId: UUID
    var quantityUsed: Int
    var quantity: Int
    var unitPrice: Double

    enum CodingKeys: String, CodingKey {
        case taskId = "taskid"
        case partId = "partid"
        case quantityUsed = "quantityused"
        case quantity
        case unitPrice = "unit_price"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        taskId = try container.decode(UUID.self, forKey: .taskId)
        partId = try container.decode(UUID.self, forKey: .partId)
        quantityUsed = try container.decodeIfPresent(Int.self, forKey: .quantityUsed) ?? 1
        quantity = try container.decodeIfPresent(Int.self, forKey: .quantity) ?? quantityUsed
        unitPrice = try container.decodeIfPresent(Double.self, forKey: .unitPrice) ?? 0
    }
}

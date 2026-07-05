import Foundation

// MARK: - Extended Inventory Item with part code
struct InventoryCSVItem: Identifiable, Hashable {
    let id: UUID
    let partname: String
    let cost: Double
    let quantityOnHand: Int
    let vehicletype: String
    let partcode: String

    // Convenience
    var displayName: String { partname }
    var stockLabel: String { "\(quantityOnHand) in stock" }
    var priceFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: cost)) ?? "$\(cost)"
    }
    
}

// MARK: - CSV Loader
enum InventoryCSVLoader {
    static func load(from fileName: String = "spare_parts") -> [InventoryCSVItem] {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "csv"),
              let content = try? String(contentsOf: url, encoding: .utf8)
        else { return [] }

        var lines = content.components(separatedBy: "\n")
        guard lines.count > 1 else { return [] }
        lines.removeFirst() // drop header

        return lines.compactMap { line -> InventoryCSVItem? in
            let columns = line.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: ",")
            guard columns.count >= 6 else { return nil }

            let idStr    = columns[0].trimmingCharacters(in: .whitespaces)
            let name     = columns[1].trimmingCharacters(in: .whitespaces)
            let cost     = Double(columns[2].trimmingCharacters(in: .whitespaces)) ?? 0
            let qty      = Int(columns[3].trimmingCharacters(in: .whitespaces)) ?? 0
            let type     = columns[4].trimmingCharacters(in: .whitespaces)
            let code     = columns[5].trimmingCharacters(in: .whitespaces)

            let id = UUID(uuidString: idStr) ?? UUID()
            return InventoryCSVItem(id: id, partname: name, cost: cost,
                                    quantityOnHand: qty, vehicletype: type, partcode: code)
        }
    }
}

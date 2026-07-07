import Foundation
import UniformTypeIdentifiers

struct CSVImportError: Identifiable, Sendable {
    let id = UUID()
    let row: Int
    let column: String
    let message: String
}

struct CSVImportResult: Sendable {
    let validRows: [InventoryPart]
    let errors: [CSVImportError]
}

enum InventoryCSVParser {

    static let expectedHeaders = [
        "name", "sku", "description", "category",
        "unit", "quantityOnHand", "reorderLevel", "unitCost"
    ]

    static let templateHeader = expectedHeaders.joined(separator: ",")

    static func generateTemplateCSV() -> String {
        [
            templateHeader,
            "Oil Filter,FLT-001,Engine oil filter for 4-cylinder vehicles,Filters,pieces,50,10,15.99",
            "Air Filter,FLT-002,Engine air filter for passenger cars,Filters,pieces,30,8,12.50",
            "Brake Pad Set,BRK-001,Front brake pad set for sedans,Brakes,set,20,5,45.00"
        ].joined(separator: "\n")
    }

    static func parse(csvData: Data) -> CSVImportResult {
        guard let content = String(data: csvData, encoding: .utf8) else {
            return CSVImportResult(
                validRows: [],
                errors: [CSVImportError(row: 0, column: "", message: "File is not valid UTF-8 text.")]
            )
        }
        return parse(csvString: content)
    }

    static func parse(csvString: String) -> CSVImportResult {
        var validRows: [InventoryPart] = []
        var errors: [CSVImportError] = []

        let lines = csvString
            .trimmingCharacters(in: .newlines)
            .components(separatedBy: "\n")

        guard lines.count >= 2 else {
            errors.append(CSVImportError(row: 0, column: "", message: "File must contain a header row and at least one data row."))
            return CSVImportResult(validRows: [], errors: errors)
        }

        let headerLine = lines[0].trimmingCharacters(in: .whitespaces)
        let headerColumns = headerLine.components(separatedBy: ",").map {
            $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }

        if headerColumns.count != expectedHeaders.count || zip(headerColumns, expectedHeaders).contains(where: { $0.lowercased() != $1.lowercased() }) {
            errors.append(CSVImportError(
                row: 1, column: "",
                message: "Header mismatch. Expected: \(expectedHeaders.joined(separator: ", ")). Got: \(headerColumns.joined(separator: ", "))."
            ))
            return CSVImportResult(validRows: [], errors: errors)
        }

        var seenSKUs = Set<String>()

        for (index, line) in lines.dropFirst().enumerated() {
            let rowNumber = index + 2
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let columns = parseCSVLine(trimmed)
            var rowErrors: [CSVImportError] = []

            let name = columns.count > 0 ? columns[0].trimmingCharacters(in: .whitespaces) : ""
            let sku = columns.count > 1 ? columns[1].trimmingCharacters(in: .whitespaces) : ""
            let description = columns.count > 2 ? columns[2].trimmingCharacters(in: .whitespaces) : ""
            let category = columns.count > 3 ? columns[3].trimmingCharacters(in: .whitespaces) : ""
            let unit = columns.count > 4 ? columns[4].trimmingCharacters(in: .whitespaces) : ""
            let quantityStr = columns.count > 5 ? columns[5].trimmingCharacters(in: .whitespaces) : ""
            let reorderStr = columns.count > 6 ? columns[6].trimmingCharacters(in: .whitespaces) : ""
            let costStr = columns.count > 7 ? columns[7].trimmingCharacters(in: .whitespaces) : ""

            if name.isEmpty {
                rowErrors.append(CSVImportError(row: rowNumber, column: "name", message: "Name is required."))
            }

            if sku.isEmpty {
                rowErrors.append(CSVImportError(row: rowNumber, column: "sku", message: "SKU is required."))
            } else if seenSKUs.contains(sku.uppercased()) {
                rowErrors.append(CSVImportError(row: rowNumber, column: "sku", message: "Duplicate SKU '\(sku)' within file."))
            } else {
                seenSKUs.insert(sku.uppercased())
            }

            let quantity: Int
            if quantityStr.isEmpty {
                quantity = 0
            } else if let q = Int(quantityStr), q >= 0 {
                quantity = q
            } else {
                rowErrors.append(CSVImportError(row: rowNumber, column: "quantityOnHand", message: "Must be a non-negative integer, got '\(quantityStr)'."))
                quantity = 0
            }

            let reorderLevel: Int
            if reorderStr.isEmpty {
                reorderLevel = 0
            } else if let r = Int(reorderStr), r >= 0 {
                reorderLevel = r
            } else {
                rowErrors.append(CSVImportError(row: rowNumber, column: "reorderLevel", message: "Must be a non-negative integer, got '\(reorderStr)'."))
                reorderLevel = 0
            }

            let unitCost: Double
            if costStr.isEmpty {
                unitCost = 0
            } else if let c = Double(costStr), c >= 0 {
                unitCost = c
            } else {
                rowErrors.append(CSVImportError(row: rowNumber, column: "unitCost", message: "Must be a non-negative number, got '\(costStr)'."))
                unitCost = 0
            }

            if !rowErrors.isEmpty {
                errors.append(contentsOf: rowErrors)
                continue
            }

            let part = InventoryPart(
                id: UUID(),
                partName: name,
                cost: unitCost,
                quantity: quantity,
                vehicleType: category,
                sku: sku,
                partDescription: description,
                category: category,
                unit: unit.isEmpty ? nil : unit,
                reorderLevel: reorderLevel,
                unitCost: unitCost,
                threshold: reorderLevel
            )
            validRows.append(part)
        }

        if validRows.isEmpty && errors.isEmpty {
            errors.append(CSVImportError(row: 0, column: "", message: "No valid data rows found in the file."))
        }

        return CSVImportResult(validRows: validRows, errors: errors)
    }

    static func generateLowStockQuotationCSV(parts: [InventoryPart]) -> String {
        let header = "name,sku,quantityOnHand,reorderLevel,suggestedQuantity,unitCost"
        var lines = [header]
        for part in parts where part.quantity <= (part.reorderLevel ?? 0) {
            let suggestedQty = max((part.reorderLevel ?? 0) * 2 - part.quantity, 0) + 1
            let costStr = String(format: "%.2f", part.unitCost ?? part.cost)
            let csvLine = [
                csvEscape(part.partName),
                csvEscape(part.sku ?? ""),
                "\(part.quantity)",
                "\(part.reorderLevel ?? 0)",
                "\(suggestedQty)",
                costStr
            ].joined(separator: ",")
            lines.append(csvLine)
        }
        return lines.joined(separator: "\n")
    }

    private static func parseCSVLine(_ line: String) -> [String] {
        var columns: [String] = []
        var current = ""
        var inQuotes = false
        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                columns.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        columns.append(current)
        return columns
    }

    static func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
}

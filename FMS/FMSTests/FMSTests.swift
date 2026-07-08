import XCTest
@testable import FMS

final class VehicleStatusDecodingTests: XCTestCase {
    func testDecodeAvailable() throws {
        let json = #""available""#
        let status = try JSONDecoder().decode(VehicleStatus.self, from: Data(json.utf8))
        XCTAssertEqual(status, .available)
    }

    func testDecodeAssigned() throws {
        let json = #""assigned""#
        let status = try JSONDecoder().decode(VehicleStatus.self, from: Data(json.utf8))
        XCTAssertEqual(status, .assigned)
    }

    func testDecodeInMaintenance() throws {
        let json = #""in_maintenance""#
        let status = try JSONDecoder().decode(VehicleStatus.self, from: Data(json.utf8))
        XCTAssertEqual(status, .inMaintenance)
    }

    func testDecodeOutOfService() throws {
        let json = #""out_of_service""#
        let status = try JSONDecoder().decode(VehicleStatus.self, from: Data(json.utf8))
        XCTAssertEqual(status, .outOfService)
    }

    func testDecodeInvalidThrows() throws {
        let json = #""bogus""#
        XCTAssertThrowsError(try JSONDecoder().decode(VehicleStatus.self, from: Data(json.utf8)))
    }

    func testAllCasesRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for status in VehicleStatus.allCases {
            let data = try encoder.encode(status)
            let decoded = try decoder.decode(VehicleStatus.self, from: data)
            XCTAssertEqual(status, decoded)
        }
    }
}

final class DriverScoreCodableTests: XCTestCase {
    func testDriverScoreRoundTrip() throws {
        let score = DriverScore(
            id: UUID(),
            driverId: UUID(),
            overallScore: 85.5,
            inspectionFalseRate: 12.3,
            geofenceViolationRate: 5.0,
            complianceViolationRate: 90.0,
            mileageAccuracy: 88.5,
            calculatedAt: Date()
        )
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(score)
        let decoded = try decoder.decode(DriverScore.self, from: data)
        XCTAssertEqual(score.id, decoded.id)
        XCTAssertEqual(score.driverId, decoded.driverId)
        XCTAssertEqual(score.overallScore, decoded.overallScore)
        XCTAssertEqual(score.inspectionFalseRate, decoded.inspectionFalseRate)
        XCTAssertEqual(score.geofenceViolationRate, decoded.geofenceViolationRate)
        XCTAssertEqual(score.mileageAccuracy, decoded.mileageAccuracy)
    }

    func testDriverScoreWithNilOptionals() throws {
        let score = DriverScore(
            id: UUID(),
            driverId: UUID(),
            overallScore: 75.0,
            inspectionFalseRate: nil,
            geofenceViolationRate: nil,
            complianceViolationRate: nil,
            mileageAccuracy: nil,
            calculatedAt: Date()
        )
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(score)
        let decoded = try decoder.decode(DriverScore.self, from: data)
        XCTAssertNil(decoded.inspectionFalseRate)
        XCTAssertNil(decoded.geofenceViolationRate)
        XCTAssertNil(decoded.mileageAccuracy)
    }

    func testDriverScoreCodingKeys() throws {
        let json = """
        {
            "id": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
            "driver_id": "A621E1F8-C36C-495A-93FC-0C247A3E6E5F",
            "overall_score": 92.0,
            "inspection_false_rate": 3.5,
            "geofence_violation_rate": 1.0,
            "compliance_violation_rate": 95.0,
            "mileage_accuracy": 90.0,
            "calculated_at": "2026-07-07T10:00:00Z"
        }
        """
        let decoded = try SharedDecoder.json.decode(DriverScore.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.overallScore, 92.0)
        XCTAssertEqual(decoded.inspectionFalseRate, 3.5)
        XCTAssertEqual(decoded.geofenceViolationRate, 1.0)
        XCTAssertEqual(decoded.mileageAccuracy, 90.0)
    }
}

final class CSVParserTests: XCTestCase {
    func testParseValidCSV() {
        let csv = """
        name,sku,description,category,unit,quantityOnHand,reorderLevel,unitCost
        Oil Filter,FLT-001,Engine oil filter,Filters,pieces,50,10,15.99
        Brake Pad Set,BRK-001,Front brake pads,Brakes,set,20,5,45.00
        """
        let result = InventoryCSVParser.parse(csvString: csv)
        XCTAssertEqual(result.errors.count, 0, "Expected no errors, got: \(result.errors)")
        XCTAssertEqual(result.validRows.count, 2)
        XCTAssertEqual(result.validRows[0].partName, "Oil Filter")
        XCTAssertEqual(result.validRows[0].sku, "FLT-001")
        XCTAssertEqual(result.validRows[0].quantity, 50)
    }

    func testParseInvalidHeader() {
        let csv = """
        wrong,header,format
        Oil Filter,FLT-001,Desc,Filters,pieces,50,10,15.99
        """
        let result = InventoryCSVParser.parse(csvString: csv)
        XCTAssertEqual(result.validRows.count, 0)
        XCTAssertGreaterThan(result.errors.count, 0)
        XCTAssertTrue(result.errors[0].message.contains("Header mismatch"))
    }

    func testParseMissingName() {
        let csv = """
        name,sku,description,category,unit,quantityOnHand,reorderLevel,unitCost
        ,FLT-001,Engine oil filter,Filters,pieces,50,10,15.99
        """
        let result = InventoryCSVParser.parse(csvString: csv)
        XCTAssertEqual(result.validRows.count, 0)
        XCTAssertTrue(result.errors.contains(where: { $0.column == "name" }))
    }

    func testParseNegativeQuantity() {
        let csv = """
        name,sku,description,category,unit,quantityOnHand,reorderLevel,unitCost
        Filter,FLT-001,Desc,Filters,pieces,-5,10,15.99
        """
        let result = InventoryCSVParser.parse(csvString: csv)
        XCTAssertEqual(result.validRows.count, 0)
        XCTAssertTrue(result.errors.contains(where: { $0.column == "quantityOnHand" }))
    }

    func testParseDuplicateSKU() {
        let csv = """
        name,sku,description,category,unit,quantityOnHand,reorderLevel,unitCost
        Filter A,FLT-001,Desc,Filters,pieces,50,10,15.99
        Filter B,FLT-001,Desc,Filters,pieces,30,5,12.00
        """
        let result = InventoryCSVParser.parse(csvString: csv)
        XCTAssertEqual(result.validRows.count, 1)
        XCTAssertTrue(result.errors.contains(where: { $0.column == "sku" && $0.message.contains("Duplicate") }))
    }

    func testParsePartiallyValid() {
        let csv = """
        name,sku,description,category,unit,quantityOnHand,reorderLevel,unitCost
        Valid Part,SKU-001,Good desc,Category,pieces,10,2,5.99
        ,SKU-002,Missing name,Category,pieces,5,1,3.00
        """
        let result = InventoryCSVParser.parse(csvString: csv)
        XCTAssertEqual(result.validRows.count, 1)
        XCTAssertEqual(result.errors.count, 1)
    }

    func testCSVEscapeNoSpecialChars() {
        XCTAssertEqual(InventoryCSVParser.csvEscape("Simple"), "Simple")
    }

    func testCSVEscapeWithComma() {
        XCTAssertEqual(InventoryCSVParser.csvEscape("Part, No. 1"), "\"Part, No. 1\"")
    }

    func testCSVEscapeWithQuote() {
        XCTAssertEqual(InventoryCSVParser.csvEscape("8\" Filter"), "\"8\"\" Filter\"")
    }

    func testCSVEscapeWithNewline() {
        XCTAssertEqual(InventoryCSVParser.csvEscape("Line1\nLine2"), "\"Line1\nLine2\"")
    }

    func testGenerateTemplateCSV() {
        let template = InventoryCSVParser.generateTemplateCSV()
        XCTAssertTrue(template.starts(with: InventoryCSVParser.templateHeader))
        XCTAssertTrue(template.contains("Oil Filter"))
    }

    func testGenerateLowStockQuotationCSV() {
        let parts = [
            InventoryPart(id: UUID(), partName: "Oil Filter", cost: 15.99, quantity: 5, vehicleType: "Filters", sku: "SKU-1", partDescription: nil, category: nil, unit: "pieces", reorderLevel: 10, unitCost: 15.99, threshold: 10),
            InventoryPart(id: UUID(), partName: "Brake Pad", cost: 45.00, quantity: 25, vehicleType: "Brakes", sku: "SKU-2", partDescription: nil, category: nil, unit: "set", reorderLevel: 5, unitCost: 45.00, threshold: 5)
        ]
        let csv = InventoryCSVParser.generateLowStockQuotationCSV(parts: parts)
        XCTAssertTrue(csv.contains("Oil Filter"))
        XCTAssertTrue(csv.contains("SKU-1"))
        XCTAssertTrue(csv.contains(",5,10,"))
        XCTAssertFalse(csv.contains("Brake Pad"))
    }

    func testParseCSVLineWithQuotedField() {
        let line = "Part Name,\"Description, with comma\",123"
        let parsed = parseCSVLineHelper(line)
        XCTAssertEqual(parsed.count, 3)
        XCTAssertEqual(parsed[1], "Description, with comma")
    }

    private func parseCSVLineHelper(_ line: String) -> [String] {
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
}

final class InspectionValidationTests: XCTestCase {
    func testInspectionCompleteAllPassed() {
        let vm = InspectionViewModel()
        vm.items[0].status = .passed
        vm.items[1].status = .passed
        vm.items[2].status = .passed
        vm.items[3].status = .passed
        vm.items[4].status = .passed
        vm.items[5].status = .passed
        XCTAssertTrue(vm.isComplete)
    }

    func testInspectionIncompleteUntested() {
        let vm = InspectionViewModel()
        XCTAssertFalse(vm.isComplete)
    }

    func testInspectionIncompleteFailedNoDetails() {
        let vm = InspectionViewModel()
        vm.items[0].status = .failed
        XCTAssertFalse(vm.isComplete)
    }

    func testInspectionIncompleteFailedNoPhoto() {
        let vm = InspectionViewModel()
        vm.items[0].status = .failed
        vm.items[0].failDescription = "Cracked"
        XCTAssertFalse(vm.isComplete)
    }

    func testInspectionIncompleteFailedNoText() {
        let vm = InspectionViewModel()
        vm.items[0].status = .failed
        vm.items[0].failImage = UIImage()
        XCTAssertFalse(vm.isComplete)
    }

    func testInspectionCompleteFailedWithDetails() {
        let vm = InspectionViewModel()
        vm.items[0].status = .passed
        vm.items[1].status = .passed
        vm.items[2].status = .passed
        vm.items[3].status = .passed
        vm.items[4].status = .passed
        vm.items[5].status = .failed
        vm.items[5].failDescription = "Worn out"
        vm.items[5].failImage = UIImage()
        XCTAssertTrue(vm.isComplete)
    }

    func testInspectionUpdatePassedClearsDetails() {
        let vm = InspectionViewModel()
        vm.updateStatus(for: vm.items[0].id, to: .failed)
        vm.updateDetails(for: vm.items[0].id, description: "Broken", image: UIImage())
        vm.updateStatus(for: vm.items[0].id, to: .passed)
        XCTAssertTrue(vm.items[0].failDescription.isEmpty)
        XCTAssertNil(vm.items[0].failImage)
    }
}

final class VehicleInspectionModelTests: XCTestCase {
    func testVehicleInspectionCodableRoundTrip() throws {
        let inspection = VehicleInspection(
            id: UUID(),
            tripId: UUID(),
            vehicleId: UUID(),
            driverId: UUID(),
            type: "pre_trip",
            status: .passed,
            odometerReading: 12345.6,
            fuelLevel: 0.75,
            notes: "All good",
            createdAt: Date()
        )
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(inspection)
        let decoded = try decoder.decode(VehicleInspection.self, from: data)
        XCTAssertEqual(inspection.id, decoded.id)
        XCTAssertEqual(inspection.type, decoded.type)
        XCTAssertEqual(inspection.status, decoded.status)
        XCTAssertEqual(inspection.odometerReading, decoded.odometerReading)
    }

    func testInspectionItemDBCodable() throws {
        let item = InspectionItemDB(
            id: UUID(),
            inspectionId: UUID(),
            itemName: "Brakes",
            status: "fail",
            failDescription: "Worn pads",
            failPhotoUrl: "https://example.com/photo.jpg",
            createdAt: Date()
        )
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(item)
        let decoded = try decoder.decode(InspectionItemDB.self, from: data)
        XCTAssertEqual(item.itemName, decoded.itemName)
        XCTAssertEqual(item.status, decoded.status)
        XCTAssertEqual(item.failDescription, decoded.failDescription)
    }

    func testInspectionItemDBCodingKeys() throws {
        let json = """
        {
            "id": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
            "inspection_id": "A621E1F8-C36C-495A-93FC-0C247A3E6E5F",
            "item_name": "Tires",
            "status": "pass",
            "fail_description": null,
            "fail_photo_url": null,
            "created_at": "2026-07-07T10:00:00Z"
        }
        """
        let decoded = try SharedDecoder.json.decode(InspectionItemDB.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.itemName, "Tires")
        XCTAssertEqual(decoded.status, "pass")
        XCTAssertNil(decoded.failDescription)
        XCTAssertNil(decoded.failPhotoUrl)
    }
}

final class DeviationAlertCodableTests: XCTestCase {
    func testDeviationAlertRoundTrip() throws {
        let alert = DeviationAlert(
            id: UUID(),
            timestamp: Date(),
            distance: 150.5,
            vehicleId: UUID(),
            geofenceId: UUID(),
            tripId: UUID()
        )
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(alert)
        let decoded = try decoder.decode(DeviationAlert.self, from: data)
        XCTAssertEqual(alert.id, decoded.id)
        XCTAssertEqual(alert.distance, decoded.distance)
        XCTAssertEqual(alert.vehicleId, decoded.vehicleId)
    }

    func testDeviationAlertCodingKeys() throws {
        let json = """
        {
            "deviationid": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
            "timestamp": "2026-07-07T10:00:00Z",
            "distance": 200.0,
            "vehicleid": "A621E1F8-C36C-495A-93FC-0C247A3E6E5F",
            "geofenceid": "B621E1F8-C36C-495A-93FC-0C247A3E6E5F",
            "tripid": "C621E1F8-C36C-495A-93FC-0C247A3E6E5F"
        }
        """
        let decoded = try SharedDecoder.json.decode(DeviationAlert.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.distance, 200.0)
        XCTAssertNotNil(decoded.geofenceId)
        XCTAssertNotNil(decoded.tripId)
    }

    func testDeviationAlertNilOptionals() throws {
        let json = """
        {
            "deviationid": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
            "timestamp": "2026-07-07T10:00:00Z",
            "distance": 100.0,
            "vehicleid": "A621E1F8-C36C-495A-93FC-0C247A3E6E5F"
        }
        """
        let decoded = try SharedDecoder.json.decode(DeviationAlert.self, from: Data(json.utf8))
        XCTAssertNil(decoded.geofenceId)
        XCTAssertNil(decoded.tripId)
    }
}

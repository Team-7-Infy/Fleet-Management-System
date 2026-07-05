import Foundation

struct Vehicle: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var make: String
    var model: String
    var year: Int
    @FormattedLicencePlate var licencePlate: String
    var status: VehicleStatus
    var vehicleType: String
    var driverId: UUID?
    var fuelType: String?

    enum CodingKeys: String, CodingKey {
        case id = "vin"
        case make
        case model
        case year
        case licencePlate = "licence_plate"
        case status
        case vehicleType = "vehicletype"
        case driverId = "driverid"
        case fuelType = "fuel_type"
    }
    
    var formattedLicencePlate: String { licencePlate }
}

@propertyWrapper
struct FormattedLicencePlate: Codable, Hashable, Sendable {
    private var value: String
    
    var wrappedValue: String {
        get {
            let raw = value.replacingOccurrences(of: " ", with: "").uppercased()
            // e.g. KA01AB1234 -> KA 01 AB 1234
            let pattern = "^([A-Z]{2})(\\d{1,2})([A-Z]{1,3})?(\\d{1,4})$"
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)) {
                var parts = [String]()
                for i in 1...4 {
                    if let range = Range(match.range(at: i), in: raw) {
                        parts.append(String(raw[range]))
                    }
                }
                return parts.joined(separator: " ")
            }
            return value
        }
        set { value = newValue }
    }
    
    init(wrappedValue: String) {
        self.value = wrappedValue
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.value = try container.decode(String.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}



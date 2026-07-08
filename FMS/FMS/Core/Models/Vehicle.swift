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
    var addedToFleetAt: Date?
    var odometer: Double?
    var maintenanceKmInterval: Int?
    var maintenanceMonthInterval: Int?
    var deletedAt: Date?
    var baseAge: Int?

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
        case addedToFleetAt = "added_to_fleet_at"
        case odometer
        case maintenanceKmInterval = "maintenance_km_interval"
        case maintenanceMonthInterval = "maintenance_month_interval"
        case deletedAt = "deleted_at"
        case baseAge = "age"
    }
    
    var formattedLicencePlate: String { licencePlate }
    
    var currentAge: Int {
        let base = baseAge ?? 0
        guard let addedDate = addedToFleetAt else { return base }
        let yearsPassed = Calendar.current.dateComponents([.year], from: addedDate, to: Date()).year ?? 0
        return base + yearsPassed
    }

    var currentAgeString: String {
        let baseYears = baseAge ?? 0
        guard let addedDate = addedToFleetAt else {
            return "\(baseYears) years 0 months"
        }
        
        let components = Calendar.current.dateComponents([.year, .month], from: addedDate, to: Date())
        let yearsPassed = components.year ?? 0
        let monthsPassed = components.month ?? 0
        
        let totalYears = baseYears + yearsPassed
        let totalMonths = monthsPassed
        
        let yearUnit = totalYears == 1 ? "year" : "years"
        let monthUnit = totalMonths == 1 ? "month" : "months"
        
        return "\(totalYears) \(yearUnit) \(totalMonths) \(monthUnit)"
    }

    init(
        id: UUID,
        make: String,
        model: String,
        year: Int,
        licencePlate: String,
        status: VehicleStatus,
        vehicleType: String,
        driverId: UUID? = nil,
        fuelType: String? = nil,
        addedToFleetAt: Date? = nil,
        odometer: Double? = nil,
        maintenanceKmInterval: Int? = nil,
        maintenanceMonthInterval: Int? = nil,
        deletedAt: Date? = nil,
        baseAge: Int? = nil
    ) {
        self.id = id
        self.make = make
        self.model = model
        self.year = year
        self._licencePlate = FormattedLicencePlate(wrappedValue: licencePlate)
        self.status = status
        self.vehicleType = vehicleType
        self.driverId = driverId
        self.fuelType = fuelType
        self.addedToFleetAt = addedToFleetAt
        self.odometer = odometer
        self.maintenanceKmInterval = maintenanceKmInterval
        self.maintenanceMonthInterval = maintenanceMonthInterval
        self.deletedAt = deletedAt
        self.baseAge = baseAge
    }
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



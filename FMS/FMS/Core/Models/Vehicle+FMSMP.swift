import Foundation

extension Vehicle {
    var name: String { "\(make) \(model)".trimmingCharacters(in: .whitespaces) }

    var sfSymbolName: String {
        FleetIcon.vehicle(type: vehicleType)
    }

    var assetImageName: String {
        let lowerType = vehicleType.lowercased()
        if lowerType.contains("bus") { return "Bus" }
        if lowerType.contains("van") { return "Van" }
        if lowerType.contains("truck") { return "Truck" }
        return "Car"
    }
    var registrationNumber: String { licencePlate }
}

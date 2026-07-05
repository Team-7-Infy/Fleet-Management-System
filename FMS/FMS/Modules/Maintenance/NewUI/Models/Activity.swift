import Foundation

struct Activity: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let date: Date
    let status: JobStatus
    var elapsedTime: TimeInterval? = nil
    var vehicleType: String? = nil
}

extension Activity {
    var assetImageName: String {
        guard let type = vehicleType else { return "Car" }
        switch type.lowercased() {
        case "car": return "Car"
        case "bus": return "Bus"
        case "truck": return "Truck"
        case "van": return "Van"
        default: return "Car"
        }
    }
}

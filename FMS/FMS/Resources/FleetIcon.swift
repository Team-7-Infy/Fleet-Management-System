import Foundation

enum FleetIcon {
    static let account = "person.circle.fill"
    static let activity = "clock.arrow.circlepath"
    static let add = "plus"
    static let calendar = "calendar"
    static let car = "car.fill"
    static let checkmark = "checkmark.circle.fill"
    static let chevronRight = "chevron.right"
    static let dashboard = "house.fill"
    static let jobs = "clipboard.fill"
    static let maintenance = "wrench.and.screwdriver.fill"
    static let photo = "photo.fill"
    static let search = "magnifyingglass"
    static let truck = "truck.box.fill"
    static let warning = "exclamationmark.triangle.fill"
    static let workOrder = "doc.text.fill"

    static func vehicle(type: String?) -> String {
        let normalized = type?.lowercased() ?? ""
        if normalized.contains("bus") { return "bus.fill" }
        if normalized.contains("truck") { return "truck.box.fill" }
        if normalized.contains("van") { return "box.truck.fill" }
        return "car.fill"
    }
}

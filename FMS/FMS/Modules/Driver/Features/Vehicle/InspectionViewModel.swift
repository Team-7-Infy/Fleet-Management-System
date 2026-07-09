import Foundation
import Combine
import UIKit

@MainActor
class InspectionViewModel: ObservableObject {
    @Published var items: [InspectionItem] = [
        InspectionItem(name: "Tires & Pressure", icon: "tire", category: "Exterior"),
        InspectionItem(name: "Brakes & Fluid", icon: "minus.circle.fill", category: "Mechanical"),
        InspectionItem(name: "Headlights & Tail Lights", icon: "headlight.high.beam.fill", category: "Electrical"),
        InspectionItem(name: "Engine Oil & Coolant", icon: "drop.fill", category: "Engine"),
        InspectionItem(name: "Mirrors & Windshield", icon: "macwindow", category: "Exterior"),
        InspectionItem(name: "Wipers & Washer Fluid", icon: "cloud.rain.fill", category: "Exterior"),
        InspectionItem(name: "Other", icon: "ellipsis.circle.fill", category: "Other")
    ]

    var categories: [String] {
        let cats = Set(items.map(\.category))
        return ["All"] + cats.sorted()
    }

    var groupedItems: [(category: String, items: [InspectionItem])] {
        Dictionary(grouping: items, by: \.category)
            .map { ($0.key, $0.value) }
            .sorted { $0.category < $1.category }
    }
    
    @Published var isSubmitting: Bool = false
    
    var isComplete: Bool {
        !items.contains(where: {
            $0.status == .untested ||
            ($0.status == .failed && ($0.failDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || $0.failImage == nil))
        })
    }
    
    func updateStatus(for id: UUID, to newStatus: InspectionItem.ItemStatus) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].status = newStatus
            // Clear details if changed to passed
            if newStatus == .passed {
                items[index].failDescription = ""
                items[index].failImage = nil
            }
        }
    }

    func updateDetails(for id: UUID, description: String, image: UIImage?) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].failDescription = description
            items[index].failImage = image
        }
    }
}

import Foundation
import Combine
import UIKit

@MainActor
class InspectionViewModel: ObservableObject {
    @Published var items: [InspectionItem] = [
        InspectionItem(name: "Tires & Pressure", icon: "tire"),
        InspectionItem(name: "Brakes & Fluid", icon: "minus.circle.fill"),
        InspectionItem(name: "Headlights & Tail Lights", icon: "headlight.high.beam.fill"),
        InspectionItem(name: "Engine Oil & Coolant", icon: "drop.fill"),
        InspectionItem(name: "Mirrors & Windshield", icon: "macwindow"),
        InspectionItem(name: "Wipers & Washer Fluid", icon: "cloud.rain.fill")
    ]
    
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

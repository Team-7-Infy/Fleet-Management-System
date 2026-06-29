import Foundation
import Combine

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
    
    // Check if every item has been marked as either passed or failed
    var isComplete: Bool {
        !items.contains(where: { $0.status == .untested })
    }
    
    func updateStatus(for id: UUID, to newStatus: InspectionItem.ItemStatus) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].status = newStatus
        }
    }
}

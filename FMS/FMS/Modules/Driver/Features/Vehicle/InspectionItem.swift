import Foundation

struct InspectionItem: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    var status: ItemStatus = .untested
    
    enum ItemStatus {
        case untested, passed, failed
    }
}

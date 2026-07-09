import Foundation
import UIKit

struct InspectionItem: Identifiable, Equatable {
    let id: UUID
    let name: String
    let icon: String
    let category: String
    var status: ItemStatus
    var failDescription: String
    var failImage: UIImage?

    init(id: UUID = UUID(), name: String, icon: String, category: String = "Other", status: ItemStatus = .untested, failDescription: String = "", failImage: UIImage? = nil) {
        self.id = id
        self.name = name
        self.icon = icon
        self.category = category
        self.status = status
        self.failDescription = failDescription
        self.failImage = failImage
    }
    
    enum ItemStatus {
        case untested, passed, failed
    }

    static func == (lhs: InspectionItem, rhs: InspectionItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.icon == rhs.icon &&
        lhs.status == rhs.status &&
        lhs.failDescription == rhs.failDescription &&
        lhs.failImage == rhs.failImage
    }
}

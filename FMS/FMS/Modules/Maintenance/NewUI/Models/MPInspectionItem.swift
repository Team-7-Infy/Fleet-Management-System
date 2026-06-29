import Foundation

struct MPInspectionItem: Identifiable, Codable, Hashable {
    let id: String
    let category: String
    let title: String
    var isComplete: Bool
}

import Foundation

struct Activity: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let date: Date
    let status: JobStatus
    var elapsedTime: TimeInterval? = nil
}

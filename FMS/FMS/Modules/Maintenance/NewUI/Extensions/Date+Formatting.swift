import Foundation

extension Date {
    var shortDateTime: String {
        formatted(date: .abbreviated, time: .shortened)
    }
}

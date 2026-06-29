import Foundation

enum AppError: LocalizedError, Equatable {
    case networkUnavailable
    case unauthorized
    case notFound(String)
    case storageFailure
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            "Network connection is unavailable."
        case .unauthorized:
            "Your session has expired."
        case .notFound(let resource):
            "\(resource) could not be found."
        case .storageFailure:
            "Local storage is unavailable."
        case .unknown(let message):
            message
        }
    }
}

import Foundation

struct AppEnvironment {
    let dependencies: AppDependencyContainer

    static let preview = AppEnvironment(dependencies: .mock())
}

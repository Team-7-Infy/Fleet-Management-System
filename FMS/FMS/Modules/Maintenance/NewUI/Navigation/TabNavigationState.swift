import Foundation
import Combine

final class TabNavigationState: ObservableObject {
    @Published var path: [AppRoute] = []

    func push(_ route: AppRoute) {
        path.append(route)
    }

    func popToRoot() {
        path.removeAll()
    }
    
    func pop() {
        if !path.isEmpty {
            path.removeLast()
        }
    }
    
}

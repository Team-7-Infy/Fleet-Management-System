import Foundation
import Combine

final class NavigationCoordinator: ObservableObject {
    @Published var selectedTab: AppTab = .dashboard
    let dashboard = TabNavigationState()
    let myJobs = TabNavigationState()
}

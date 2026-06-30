import Foundation
import Combine

class DashboardViewModel: ObservableObject {
    @Published var driverName: String = ""
    @Published var safetyScore: Int = 0
    @Published var activeTripId: String? = nil
    @Published var assignedVehicle: String = ""
    @Published var fuelLevel: Double = 0.0
    @Published var pendingTasks: Int = 0

    func fetchDashboardData() {
    }
}

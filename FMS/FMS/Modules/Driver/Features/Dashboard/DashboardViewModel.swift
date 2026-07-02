import Foundation
import Combine

class DashboardViewModel: ObservableObject {
    private let services: AppServices
    private let driver: Driver?
    private let user: User
    private var cancellables = Set<AnyCancellable>()

    @Published var driverName: String = ""
    @Published var safetyScore: Int = 0
    @Published var activeTripId: String? = nil
    @Published var assignedVehicle: String = ""
    @Published var fuelLevel: Double = 0.0
    @Published var pendingTasks: Int = 0
    @Published var estimatedRangeKm: Double = 0.0
    @Published var mileageKmPerLiter: Double = 0.0

    init(services: AppServices, driver: Driver?, user: User) {
        self.services = services
        self.driver = driver
        self.user = user
        self.driverName = "\(user.fName) \(user.lName)"
    }

    func fetchDashboardData() async {
        guard let driver = driver else { return }
        do {
            async let fetchedTrips = services.tripService.fetchTrips(forDriverId: driver.id)
            async let fetchedVehicles = services.vehicleService.fetchVehicles(forDriverId: driver.id)

            let (trips, vehicles) = try await (fetchedTrips, fetchedVehicles)
            let activeTrip = trips.first(where: { $0.status == .inProgress })
            let assigned = vehicles.first

            await MainActor.run {
                activeTripId = activeTrip?.id.uuidString
                pendingTasks = trips.filter { $0.status == .pending || $0.status == .accepted }.count
                assignedVehicle = assigned?.licencePlate ?? "N/A"
                fuelLevel = 0.5
                mileageKmPerLiter = 12.0
                estimatedRangeKm = 600.0
            }
        } catch {
            await MainActor.run {
                activeTripId = nil
                pendingTasks = 0
                assignedVehicle = "N/A"
                fuelLevel = 0.0
            }
        }
    }
}

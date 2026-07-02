import Foundation
import Combine

class FuelViewModel: ObservableObject {
    private var cancellables = Set<AnyCancellable>()

    @Published var fuelHistory: [FuelRecord] = []
    @Published var isSubmitting: Bool = false
    @Published var showSuccessAlert: Bool = false

    init() {
        LocalDataStore.shared.$fuelHistory.assign(to: &$fuelHistory)
    }

    func submitFuelRequest(vehicleId: String, fuelType: FuelRecord.FuelType, amount: Double, currentLevel: Double) {
        isSubmitting = true

        LocalDataStore.shared.submitFuelRequest(vehicleId: vehicleId, fuelType: fuelType, amount: amount, currentLevel: currentLevel)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isSubmitting = false
            self.showSuccessAlert = true
        }
    }
}

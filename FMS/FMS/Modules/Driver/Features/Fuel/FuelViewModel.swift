import Foundation
import Combine

class FuelViewModel: ObservableObject {
    @Published var fuelHistory: [FuelRecord] = []
    @Published var isSubmitting: Bool = false
    @Published var showSuccessAlert: Bool = false

    func submitFuelRequest(vehicleId: String, fuelType: FuelRecord.FuelType, amount: Double, currentLevel: Double) {
    }
}

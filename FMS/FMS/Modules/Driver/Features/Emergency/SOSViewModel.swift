import Foundation
import CoreLocation
import Combine

class SOSViewModel: ObservableObject {
    @Published var isActivated: Bool = false
    @Published var countdown: Int = 5
    @Published var alertSent: Bool = false

    private var timer: Timer?
    private var driverId: String = ""
    private var vehicleId: String = ""

    func configure(driverId: String, vehicleId: String) {
        self.driverId = driverId
        self.vehicleId = vehicleId
    }

    func triggerSOSSequence(currentLocation: CLLocation?) {
        isActivated = true
        countdown = 5
        alertSent = false

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.countdown > 1 {
                self.countdown -= 1
            } else {
                self.dispatchEmergencyAlert(location: currentLocation)
            }
        }
    }

    func cancelSOS() {
        timer?.invalidate()
        timer = nil
        isActivated = false
        countdown = 5
    }

    private func dispatchEmergencyAlert(location: CLLocation?) {
        timer?.invalidate()

        let lat = location?.coordinate.latitude ?? 0.0
        let lng = location?.coordinate.longitude ?? 0.0

        let payload: [String: Any] = [
            "driver_id": driverId,
            "vehicle_id": vehicleId,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "latitude": lat,
            "longitude": lng,
            "type": "CRITICAL_SOS"
        ]

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.alertSent = true
            print("SOS DISPATCHED: \(payload)")
        }
    }
}

import Foundation
import CoreLocation
import Combine

@MainActor
class SOSViewModel: ObservableObject {
    @Published var isActivated: Bool = false
    @Published var countdown: Int = 5
    @Published var alertSent: Bool = false
    @Published var currentEvent: SOSEvent?

    private var timer: Timer?
    private var sosService: SOSServiceProtocol?
    private var notificationService: NotificationServiceProtocol?
    private var driverId: UUID?
    private var vehicleId: String?
    private var activeTripId: UUID?

    func configure(
        sosService: SOSServiceProtocol,
        notificationService: NotificationServiceProtocol,
        driverId: UUID,
        vehicleId: String?,
        activeTripId: UUID?
    ) {
        self.sosService = sosService
        self.notificationService = notificationService
        self.driverId = driverId
        self.vehicleId = vehicleId
        self.activeTripId = activeTripId
    }

    func triggerSOSSequence(currentLocation: CLLocation?) {
        isActivated = true
        countdown = 5
        alertSent = false

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            if countdown > 1 {
                countdown -= 1
            } else {
                dispatchEmergencyAlert(location: currentLocation)
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

        guard let sosService, let driverId else {
            alertSent = true
            print("SOS: services not configured")
            return
        }

        let lat = location?.coordinate.latitude ?? 0.0
        let lng = location?.coordinate.longitude ?? 0.0

        let event = SOSEvent(
            id: UUID(),
            tripId: activeTripId,
            driverId: driverId,
            vehicleId: vehicleId,
            type: "critical",
            status: .pending,
            latitude: lat,
            longitude: lng,
            resolvedBy: nil,
            resolvedAt: nil,
            notes: nil,
            createdAt: Date()
        )

        Task {
            do {
                currentEvent = try await sosService.createEvent(event)

                if let notificationService {
                    let notification = AppNotification(
                        id: UUID(),
                        title: "CRITICAL: Driver SOS Emergency",
                        message: "Driver has triggered an SOS alert from location (\(lat), \(lng)).",
                        type: "sos_emergency",
                        isRead: false,
                        referenceId: activeTripId,
                        recipientId: nil,
                        createdAt: Date()
                    )
                    try await notificationService.createNotification(notification)
                }

                alertSent = true
            } catch {
                print("SOS: failed to persist event — \(error)")
                alertSent = true
            }
        }
    }
}

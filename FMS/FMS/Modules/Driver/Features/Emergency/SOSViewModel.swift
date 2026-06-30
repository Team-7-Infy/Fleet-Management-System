//
//  SOSViewModel.swift
//  FMSD
//
//  Created by Dev Jain on 24/06/26.
//


import Foundation
import CoreLocation
import Combine

class SOSViewModel: ObservableObject {
    @Published var isActivated: Bool = false
    @Published var countdown: Int = 5
    @Published var alertSent: Bool = false
    
    private var timer: Timer?
    
    // Called when the user successfully completes the "Hold" action
    func triggerSOSSequence(currentLocation: CLLocation?) {
        isActivated = true
        countdown = 5
        alertSent = false
        
        // Start a 5-second countdown to allow the driver to cancel if accidental
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if self.countdown > 1 {
                self.countdown -= 1
            } else {
                self.dispatchEmergencyAlert(location: currentLocation)
            }
        }
    }
    
    // Called if the user taps "Cancel" during the countdown
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
        
        // Construct the emergency payload
        let payload = [
            "driver_id": "DRV-1029",
            "vehicle_id": "KA-01-HC-1234",
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "latitude": lat,
            "longitude": lng,
            "type": "CRITICAL_SOS"
        ] as [String : Any]
        
        // Simulate high-priority API Call and SMS Webhook trigger
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.alertSent = true
            // In production, this would trigger Twilio/SNS to blast SMS to emergency contacts
            print("SOS DISPATCHED: \(payload)")
        }
    }
}

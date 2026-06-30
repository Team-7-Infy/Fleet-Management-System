//
//  IncidentViewModel.swift
//  FMSD
//
//  Created by Dev Jain on 24/06/26.
//


import Foundation
import CoreLocation
import Combine

class IncidentViewModel: ObservableObject {
    @Published var selectedType: Incident.IncidentType = .accident
    @Published var incidentDescription: String = ""
    @Published var capturedPhotos: [String] = [] // Storing mock file paths
    
    @Published var isSubmitting: Bool = false
    @Published var submissionSuccess: Bool = false
    @Published var errorMessage: String? = nil
    
    // Validates that the driver has provided the minimum required information
    var isValid: Bool {
        !incidentDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    func submitReport(currentLocation: CLLocation?) {
        guard isValid else { return }
        
        isSubmitting = true
        errorMessage = nil
        
        // Construct the payload
        let report = Incident(
            date: Date(),
            type: selectedType,
            description: incidentDescription,
            location: currentLocation?.coordinate,
            photoURLs: capturedPhotos,
            status: .submitted
        )
        
        // Simulate Network/API Request to Fleet Manager
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.isSubmitting = false
            self.submissionSuccess = true
            // In a real application, you would save 'report' to CoreData or send via API here
        }
    }
    
    func simulatePhotoCapture() {
        // Simulate adding a photo from the device camera
        capturedPhotos.append("mock_photo_\(UUID().uuidString).jpg")
    }
}

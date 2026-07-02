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
    @Published var capturedPhotos: [String] = []

    @Published var isSubmitting: Bool = false
    @Published var submissionSuccess: Bool = false
    @Published var errorMessage: String? = nil

    var isValid: Bool {
        !incidentDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func submitReport(currentLocation: CLLocation?, tripId: String?) {
        guard isValid else { return }

        isSubmitting = true
        errorMessage = nil

        LocalDataStore.shared.submitIncident(
            type: selectedType,
            description: incidentDescription,
            photos: capturedPhotos,
            latitude: currentLocation?.coordinate.latitude,
            longitude: currentLocation?.coordinate.longitude,
            tripId: tripId
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isSubmitting = false
            self.submissionSuccess = true
        }
    }

    func simulatePhotoCapture() {
        capturedPhotos.append("mock_photo_\(UUID().uuidString).jpg")
    }
}

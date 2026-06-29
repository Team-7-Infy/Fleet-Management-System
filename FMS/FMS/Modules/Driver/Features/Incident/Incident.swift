//
//  Incident.swift
//  FMSD
//
//  Created by Dev Jain on 24/06/26.
//


import Foundation
import CoreLocation

struct Incident: Identifiable {
    let id = UUID()
    let date: Date
    var type: IncidentType
    var description: String
    var location: CLLocationCoordinate2D?
    var photoURLs: [String] // Simulated local paths or remote URLs
    var status: IncidentStatus
    
    enum IncidentType: String, CaseIterable {
        case accident = "Accident"
        case vehicleDamage = "Vehicle Damage"
        case trafficViolation = "Traffic Violation"
        case theft = "Theft/Vandalism"
        case other = "Other"
    }
    
    enum IncidentStatus: String {
        case submitted = "Submitted"
        case underReview = "Under Review"
        case resolved = "Resolved"
    }
}
//
//  PerformanceMetrics.swift
//  FMSD
//
//  Created by Dev Jain on 24/06/26.
//


import Foundation
import Combine
struct PerformanceMetrics {
    var safetyScore: Int           // 0 to 100
    var fuelEfficiency: Double     // km per liter (or MPG)
    var tripsCompleted: Int
    var distanceCovered: Double    // Total km/miles
    var onTimeDeliveryRate: Double // Percentage (0.0 to 1.0)
    var vehicleCareScore: Int      // 0 to 100 (based on inspection compliance)
    
    // Sub-metrics that negatively impact the safety score
    var harshBrakingEvents: Int
    var speedingEvents: Int
    var idleTimeMinutes: Int
}

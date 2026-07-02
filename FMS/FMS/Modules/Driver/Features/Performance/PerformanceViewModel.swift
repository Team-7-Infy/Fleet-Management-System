//
//  PerformanceViewModel.swift
//  FMSD
//
//  Created by Dev Jain on 24/06/26.
//


import Foundation
import SwiftUI
import Combine

class PerformanceViewModel: ObservableObject {
    @Published var metrics: PerformanceMetrics?
    @Published var isLoading: Bool = true
    
    init() {
        fetchMetrics()
    }
    
    func fetchMetrics() {
        // Simulate an API call to the fleet telemetry server
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.metrics = PerformanceMetrics(
                safetyScore: 88,
                fuelEfficiency: 14.5,
                tripsCompleted: 42,
                distanceCovered: 3150.5,
                onTimeDeliveryRate: 0.94,
                vehicleCareScore: 95,
                harshBrakingEvents: 3,
                speedingEvents: 1,
                idleTimeMinutes: 45
            )
            self.isLoading = false
        }
    }
    
    // Helper to determine the color of the safety score ring
    func scoreColor(for score: Int) -> Color {
        switch score {
        case 90...100: return FleetPalette.success
        case 75...89: return FleetPalette.warning
        default: return FleetPalette.danger
        }
    }
    
    // Helper to format percentages
    func formatPercentage(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "0%"
    }
}

import Foundation
import SwiftUI
import Combine

class PerformanceViewModel: ObservableObject {
    @Published var metrics: PerformanceMetrics?
    @Published var isLoading: Bool = true
    private var tripService: TripService
    private var driverId: UUID?

    init(tripService: TripService = TripService(supabase: SupabaseService()), driverId: UUID? = nil) {
        self.tripService = tripService
        self.driverId = driverId
        fetchMetrics()
    }

    func fetchMetrics() {
        Task {
            let allTrips: [Trip]
            if let driverId = driverId {
                allTrips = await (try? tripService.fetchTrips(forDriverId: driverId)) ?? []
            } else {
                allTrips = await (try? tripService.fetchTrips()) ?? []
            }
            let completed = allTrips.filter { $0.status == .completed }.count

            await MainActor.run {
                self.metrics = PerformanceMetrics(
                    safetyScore: 85,
                    fuelEfficiency: 14.5,
                    tripsCompleted: completed,
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
    }
    
    func scoreColor(for score: Int) -> Color {
        switch score {
        case 90...100: return .green
        case 75...89: return .orange
        default: return .red
        }
    }
    
    func formatPercentage(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "0%"
    }
}

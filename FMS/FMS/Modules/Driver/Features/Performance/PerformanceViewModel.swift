import Foundation
import SwiftUI
import Combine

class PerformanceViewModel: ObservableObject {
    @Published var metrics: PerformanceMetrics?
    @Published var isLoading: Bool = true

    private let tripService: TripService
    private let userManagementService: UserManagementServiceProtocol
    private let driverId: UUID

    init(tripService: TripService, userManagementService: UserManagementServiceProtocol, driverId: UUID) {
        self.tripService = tripService
        self.userManagementService = userManagementService
        self.driverId = driverId
        fetchMetrics()
    }

    func fetchMetrics() {
        Task {
            do {
                let allTrips = try await tripService.fetchTrips(forDriverId: driverId)
                let completed = allTrips.filter { $0.status == .completed }
                let totalDistance = completed.compactMap(\.distanceKm).reduce(0.0, +)

                let score = try? await userManagementService.fetchDriverScore(driverId: driverId)

                let complianceRate = (score?.complianceViolationRate ?? 100.0) / 100.0
                let hasTrips = !completed.isEmpty
                let totalFuelConsumed = completed.compactMap(\.fuelConsumed).reduce(0, +)
                let fuel = totalFuelConsumed > 0 && totalDistance > 0 ? totalDistance / totalFuelConsumed : (hasTrips ? 14.5 : 0.0)
                let compliance = hasTrips ? complianceRate : 0.0
                let careScore = hasTrips ? Int(score?.inspectionFalseRate ?? 75.0) : 0
                let safetyScoreVal = Int(score?.overallScore ?? 75)
                let geofenceEvents = score?.geofenceEventCount ?? 0
                let speedingEvents = score?.speedingEventCount ?? 0

                await MainActor.run {
                    self.metrics = PerformanceMetrics(
                        safetyScore: safetyScoreVal,
                        fuelEfficiency: fuel,
                        tripsCompleted: completed.count,
                        distanceCovered: totalDistance,
                        onTimeDeliveryRate: compliance,
                        vehicleCareScore: careScore,
                        harshBrakingEvents: geofenceEvents,
                        speedingEvents: speedingEvents,
                        idleTimeMinutes: 45
                    )
                    self.isLoading = false
                }
            } catch {
                print("Failed to load driver performance metrics: \(error)")
                await MainActor.run { self.isLoading = false }
            }
        }
    }
    
    func scoreColor(for score: Int) -> Color {
        switch score {
        case 80...100: return Color.blue
        case 65...79: return Color.yellow
        case 50...64: return Color.orange
        default: return Color.red
        }
    }
    
    func formatPercentage(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "0%"
    }
}

import Foundation
import Combine
import SwiftUI
final class VehicleDetailsViewModel: ObservableObject {
    @Published private(set) var vehicle: Vehicle?
    @Published private(set) var assignedWorkOrders: [WorkOrder] = []
    @Published private(set) var completedWorkOrders: [WorkOrder] = []
    @Published private(set) var state: LoadableState<Void> = .idle

    private let vehicleID: Vehicle.ID
    private let vehicleService: any VehicleServicing
    private let workOrderService: any WorkOrderServicing

    init(vehicleID: Vehicle.ID, dependencies: AppDependencyContainer) {
        self.vehicleID = vehicleID
        vehicleService = dependencies.vehicleService
        workOrderService = dependencies.workOrderService
    }

    func load() async {
        state = .loading
        do {
            vehicle = try await vehicleService.vehicle(id: vehicleID)
            let allWorkOrders = try await workOrderService.assignedWorkOrders().filter { $0.vehicleID == vehicleID.uuidString }
            
            await MainActor.run {
                self.assignedWorkOrders = allWorkOrders.filter { $0.status != .completed }
                self.completedWorkOrders = allWorkOrders.filter { $0.status == .completed }
            }
            
            state = .loaded(())
        } catch let error as AppError {
            state = .failed(error)
        } catch {
            state = .failed(.unknown(error.localizedDescription))
        }
    }

    var dynamicStatusTitle: String {
        assignedWorkOrders.isEmpty ? "Ready for Trip" : "Under Maintenance"
    }
    
    var dynamicStatusColor: SwiftUI.Color {
        assignedWorkOrders.isEmpty ? .green : .orange
    }
    
    var dynamicStatusIcon: String {
        assignedWorkOrders.isEmpty ? "checkmark.circle" : "wrench.and.screwdriver"
    }
}

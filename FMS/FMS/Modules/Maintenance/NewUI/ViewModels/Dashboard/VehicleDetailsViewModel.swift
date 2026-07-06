import Foundation
import Combine
import SwiftUI
final class VehicleDetailsViewModel: ObservableObject {
    @Published private(set) var vehicle: Vehicle?
    @Published private(set) var assignedWorkOrders: [WorkOrder] = []
    @Published private(set) var completedWorkOrders: [WorkOrder] = []
    @Published private(set) var state: LoadableState<Void> = .idle
    @Published private(set) var currentUserID: String?

    private let vehicleID: Vehicle.ID
    private let vehicleService: any VehicleServicing
    private let workOrderService: any WorkOrderServicing
    private let authService: any AuthServicing

    init(vehicleID: Vehicle.ID, dependencies: AppDependencyContainer) {
        self.vehicleID = vehicleID
        vehicleService = dependencies.vehicleService
        workOrderService = dependencies.workOrderService
        authService = dependencies.authService
    }

    func load() async {
        state = .loading
        do {
            vehicle = try await vehicleService.vehicle(id: vehicleID)
            let allWorkOrders = try await workOrderService.assignedWorkOrders().filter { $0.vehicleID.caseInsensitiveCompare(vehicleID.uuidString) == .orderedSame }
            
            await MainActor.run {
                self.assignedWorkOrders = allWorkOrders.filter { $0.status != .completed && $0.status != .fake }
                self.completedWorkOrders = allWorkOrders.filter { $0.status == .completed || $0.status == .fake }
                self.state = .loaded(())
                
                Task {
                    if let user = try? await authService.currentUser() {
                        self.currentUserID = user.id.uuidString
                    }
                }
            }
        } catch let error as AppError {
            state = .failed(error)
        } catch {
            state = .failed(.unknown(error.localizedDescription))
        }
    }

    func submitReport(workOrderID: WorkOrder.ID, reason: String, photos: [Data]) async throws {
        state = .loading
        do {
            try await workOrderService.reportInvalidWorkOrder(id: workOrderID, reason: reason, photos: photos)
            
            // Re-load to reflect changes
            await load()
        } catch let error as AppError {
            state = .failed(error)
            throw error
        } catch {
            state = .failed(.unknown(error.localizedDescription))
            throw error
        }
    }

    var dynamicStatusTitle: String {
        assignedWorkOrders.isEmpty ? "Ready for Trip" : "Under Maintenance"
    }
    
    var dynamicStatusColor: SwiftUI.Color {
        assignedWorkOrders.isEmpty ? AppColor.success : AppColor.warning
    }
    
    var dynamicStatusIcon: String {
        assignedWorkOrders.isEmpty ? "checkmark.circle" : "wrench.and.screwdriver"
    }
}

import Foundation
import Combine

final class PastWorkOrderDetailsViewModel: ObservableObject {
    @Published private(set) var workOrder: WorkOrder?
    @Published private(set) var vehicle: Vehicle?
    @Published private(set) var reportedBy: UserProfile?
    @Published private(set) var assignedBy: UserProfile?
    @Published private(set) var state: LoadableState<Void> = .idle
    
    private let workOrderID: WorkOrder.ID
    private let workOrderService: any WorkOrderServicing
    private let vehicleService: any VehicleServicing
    private let authService: any AuthServicing
    
    init(workOrderID: WorkOrder.ID, dependencies: AppDependencyContainer) {
        self.workOrderID = workOrderID
        self.workOrderService = dependencies.workOrderService
        self.vehicleService = dependencies.vehicleService
        self.authService = dependencies.authService
    }
    
    func load() async {
        state = .loading
        do {
            let fetched = try await workOrderService.workOrder(id: workOrderID)
            var fetchedVehicle: Vehicle?
            if let vinString = fetched.taskVehicles?.first?.vin, let vin = UUID(uuidString: vinString.uuidString) {
                fetchedVehicle = try? await vehicleService.vehicle(id: vin)
            }
            
            var scheduledByUser: UserProfile?
            if let scheduledBy = fetched.scheduledBy {
                scheduledByUser = try? await authService.getUserProfile(by: scheduledBy)
            }
            
            var executedByUser: UserProfile?
            if let executedBy = fetched.executedBy {
                executedByUser = try? await authService.getUserProfile(by: executedBy)
            }
            
            await MainActor.run {
                self.workOrder = fetched
                self.vehicle = fetchedVehicle
                self.reportedBy = executedByUser // Mechanic who completed/reported it
                self.assignedBy = scheduledByUser // Fleet manager who assigned it
                self.state = .loaded(())
            }
        } catch let error as AppError {
            await MainActor.run { self.state = .failed(error) }
        } catch {
            await MainActor.run { self.state = .failed(.unknown(error.localizedDescription)) }
        }
    }
    
    var formattedLaborTime: String {
        guard let elapsed = workOrder?.elapsedTime else { return "0s" }
        let hours = Int(elapsed) / 3600
        let minutes = (Int(elapsed) % 3600) / 60
        let seconds = Int(elapsed) % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    var formattedPartsCost: String {
        guard let order = workOrder else { return "₹0" }
        let parts = order.mappedParts.isEmpty ? order.usedParts : order.mappedParts
        let partsCost = parts.reduce(Decimal(0)) { $0 + ($1.unitPrice * Decimal($1.quantity)) }
        return formatCurrency(partsCost)
    }
    
    var formattedLaborCost: String {
        guard let order = workOrder else { return "₹0" }
        let parts = order.mappedParts.isEmpty ? order.usedParts : order.mappedParts
        let partsCost = parts.reduce(Double(0)) { $0 + (Double(truncating: $1.unitPrice as NSNumber) * Double($1.quantity)) }
        let total = order.totalCostDB ?? 0.0
        let labor = max(0, total - partsCost)
        return formatCurrency(Decimal(labor))
    }
    
    var formattedTotalCost: String {
        guard let order = workOrder else { return "₹0" }
        if let total = order.totalCostDB {
            return formatCurrency(Decimal(total))
        }
        let parts = order.mappedParts.isEmpty ? order.usedParts : order.mappedParts
        let partsCost = parts.reduce(Decimal(0)) { $0 + ($1.unitPrice * Decimal($1.quantity)) }
        return formatCurrency(partsCost)
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "₹0"
    }
    
    var usedParts: [PartItem] {
        guard let order = workOrder else { return [] }
        return order.mappedParts.isEmpty ? order.usedParts : order.mappedParts
    }
}

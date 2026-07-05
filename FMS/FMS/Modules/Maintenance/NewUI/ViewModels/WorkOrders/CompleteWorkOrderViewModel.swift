import Foundation
import Combine
import Combine

struct WorkOrderDraft: Codable {
    let elapsedTime: TimeInterval
    let remarks: String
    let laborCost: String
    let usedParts: [PartItem]
    let timestamp: Date
}

final class CompleteWorkOrderViewModel: ObservableObject {
    @Published private(set) var workOrder: WorkOrder?
    @Published var state: LoadableState<Void> = .idle
    @Published var showError = false
    @Published var errorMessage: String? = nil
    
    // Form State
    @Published var elapsedTime: TimeInterval = 0
    @Published var currentVehicleType: String?
    @Published var laborCost: String = ""
    @Published var remarks: String = ""
    
    private var startTime: Date?
    var wasCompleted = false
    
    // Mock parts exactly matching the design
    @Published var usedParts: [PartItem] = []
    @Published var inventoryParts: [Part] = []
    
    var totalPartsCost: Decimal {
        usedParts.reduce(0) { $0 + ($1.unitPrice * Decimal($1.quantity)) }
    }
    
    var totalLaborCost: Decimal {
        Decimal(string: laborCost) ?? 0
    }
    
    var totalCost: Decimal {
        totalPartsCost + totalLaborCost
    }

    private let workOrderID: WorkOrder.ID
    private let workOrderService: any WorkOrderServicing
    private let activityService: any ActivityServicing
    private let vehicleService: any VehicleServicing

    init(workOrderID: WorkOrder.ID, dependencies: AppDependencyContainer) {
        self.workOrderID = workOrderID
        workOrderService = dependencies.workOrderService
        activityService = dependencies.activityService
        vehicleService = dependencies.vehicleService
    }

    private var isLoaded = false
    
    func load() async {
        if isLoaded { return }
        state = .loading
        do {
            workOrder = try await workOrderService.workOrder(id: workOrderID)
            inventoryParts = try await workOrderService.fetchInventory()
            
            var fetchedVehicleType: String? = nil
            if let vinStr = workOrder?.vehicleID, let vin = UUID(uuidString: vinStr) {
                if let vehicle = try? await vehicleService.vehicle(id: vin) {
                    fetchedVehicleType = vehicle.vehicleType
                }
            }
            
            await MainActor.run {
                if let wo = workOrder {
                    self.elapsedTime = wo.elapsedTime ?? 0
                    if !wo.mappedParts.isEmpty {
                        self.usedParts = wo.mappedParts
                    } else if !wo.usedParts.isEmpty {
                        self.usedParts = wo.usedParts
                    } else {
                        self.usedParts = []
                    }
                    self.remarks = wo.remarks ?? ""
                    
                    if let totalCostDB = wo.totalCostDB {
                        let partsCost = self.usedParts.reduce(0.0) { $0 + (Double(truncating: $1.unitPrice as NSNumber) * Double($1.quantity)) }
                        let calculatedLabor = totalCostDB - partsCost
                        if calculatedLabor > 0 {
                            self.laborCost = String(format: "%.2f", calculatedLabor)
                        } else {
                            self.laborCost = ""
                        }
                    }
                    
                    // Check for local draft
                    let draftKey = "draft_wo_\(self.workOrderID)"
                    if let data = UserDefaults.standard.data(forKey: draftKey),
                       let draft = try? JSONDecoder().decode(WorkOrderDraft.self, from: data) {
                        
                        // Merge draft if it has data
                        if draft.elapsedTime > self.elapsedTime {
                            self.elapsedTime = draft.elapsedTime
                        }
                        if !draft.remarks.isEmpty {
                            self.remarks = draft.remarks
                        }
                        if !draft.laborCost.isEmpty {
                            self.laborCost = draft.laborCost
                        }
                        if !draft.usedParts.isEmpty {
                            self.usedParts = draft.usedParts
                        }
                    }
                    
                    self.currentVehicleType = fetchedVehicleType
                }
                self.startTime = Date()
                self.isLoaded = true
                state = .loaded(())
            }
            // Mark task as in-progress immediately when the view loads
            if workOrder?.status != .inProgress {
                try? await workOrderService.updateWorkOrder(
                    id: workOrderID,
                    status: .inProgress,
                    elapsedTime: elapsedTime,
                    parts: usedParts,
                    remarks: nil,
                    totalCost: nil
                )
            }
        } catch let error as AppError {
            state = .failed(error)
        } catch {
            state = .failed(.unknown(error.localizedDescription))
        }
    }
    
    func completeWorkOrder() async {
        wasCompleted = true
        if let start = startTime {
            elapsedTime += Date().timeIntervalSince(start)
        }

        do {
            try await workOrderService.updateWorkOrder(
                id: workOrderID,
                status: .completed,
                elapsedTime: elapsedTime,
                parts: usedParts,
                remarks: remarks,
                totalCost: totalCost
            )
            
            if let wo = workOrder {
                let activity = Activity(
                    id: UUID().uuidString,
                    title: wo.title,
                    subtitle: "For \(wo.vehicleName)",
                    date: Date(),
                    status: .completed,
                    elapsedTime: self.elapsedTime
                )
                try await activityService.logActivity(activity)
            }
            
            // Clear local draft upon completion
            UserDefaults.standard.removeObject(forKey: "draft_wo_\(workOrderID)")
            
            NotificationCenter.default.post(name: NSNotification.Name("WorkOrderUpdated"), object: nil)
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to complete work order: \(error.localizedDescription)"
                self.showError = true
            }
        }
    }
    
    func pauseWorkOrder() {
        if wasCompleted { return }
        
        var currentElapsedTime = elapsedTime
        if let start = startTime {
            currentElapsedTime += Date().timeIntervalSince(start)
        }
        
        let partsToSave = usedParts
        let currentRemarks = remarks
        let currentCost = totalCost
        
        // Save local draft
        let draft = WorkOrderDraft(
            elapsedTime: currentElapsedTime,
            remarks: currentRemarks,
            laborCost: laborCost,
            usedParts: partsToSave,
            timestamp: Date()
        )
        if let data = try? JSONEncoder().encode(draft) {
            UserDefaults.standard.set(data, forKey: "draft_wo_\(workOrderID)")
        }
        
        Task {
            try? await workOrderService.updateWorkOrder(
                id: workOrderID,
                status: .inProgress,
                elapsedTime: currentElapsedTime,
                parts: partsToSave,
                remarks: currentRemarks.isEmpty ? nil : currentRemarks,
                totalCost: currentCost
            )
        }
    }
    
    func incrementPart(id: String) {
        guard let index = usedParts.firstIndex(where: { $0.id == id }) else { return }
        
        let requestedQty = usedParts[index].quantity + 1
        let availableQty = inventoryParts.first(where: { $0.id.uuidString == id })?.currentQuantity ?? 0
        
        if requestedQty <= availableQty {
            usedParts[index].quantity = requestedQty
        } else {
            showError(message: "Cannot add more. Only \(availableQty) in stock.")
        }
    }
    
    func decrementPart(id: String) {
        if let index = usedParts.firstIndex(where: { $0.id == id }) {
            if usedParts[index].quantity > 1 {
                usedParts[index].quantity -= 1
            }
        }
    }
    
    func removePart(id: String) {
        usedParts.removeAll(where: { $0.id == id })
    }
    
    func addPart(_ part: SparePart, quantity: Int) {
        let availableQty = part.currentQuantity
        let currentQty = usedParts.first(where: { $0.id == part.id.uuidString })?.quantity ?? 0
        let requestedQty = currentQty + quantity
        
        if requestedQty > availableQty {
            showError(message: "Cannot add more. Only \(availableQty) in stock.")
            return
        }
        
        if let index = usedParts.firstIndex(where: { $0.id == part.id.uuidString }) {
            usedParts[index].quantity += quantity
        } else {
            let newItem = PartItem(
                id: part.id.uuidString,
                name: part.name,
                quantity: quantity,
                unitPrice: part.unitPrice
            )
            usedParts.append(newItem)
        }
    }
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}

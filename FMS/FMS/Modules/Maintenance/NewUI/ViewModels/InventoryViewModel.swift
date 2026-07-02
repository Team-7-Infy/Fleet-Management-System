import Foundation
import Combine

// MARK: - Vehicle Category Filter
enum VehicleCategory: String, CaseIterable, Identifiable {
    case all   = "All"
    case car   = "Car"
    case van   = "Van"
    case truck = "Truck"
    case bus   = "Bus"

    var id: String { rawValue }
}

// MARK: - Inventory View Model
@MainActor
final class InventoryViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var selectedCategory: VehicleCategory = .all
    @Published private(set) var allItems: [InventoryCSVItem] = []

    /// The item whose threshold sheet is currently presented.
    @Published var thresholdSheetItem: InventoryCSVItem?

    /// Shared threshold store — injected for testability, defaulting to .shared.
    let thresholdStore: ThresholdStore

    init(thresholdStore: ThresholdStore = .shared) {
        self.thresholdStore = thresholdStore
        allItems = InventoryCSVLoader.load()
    }

    // MARK: - Filtering

    var filteredItems: [InventoryCSVItem] {
        allItems.filter { item in
            let matchesCategory: Bool
            if selectedCategory == .all {
                matchesCategory = true
            } else {
                matchesCategory = item.vehicletype.caseInsensitiveCompare(selectedCategory.rawValue) == .orderedSame
            }

            let matchesSearch: Bool
            if searchText.isEmpty {
                matchesSearch = true
            } else {
                matchesSearch = item.partname.localizedCaseInsensitiveContains(searchText)
                    || item.partcode.localizedCaseInsensitiveContains(searchText)
                    || item.vehicletype.localizedCaseInsensitiveContains(searchText)
            }

            return matchesCategory && matchesSearch
        }
    }

    // MARK: - Threshold Helpers

    func threshold(for item: InventoryCSVItem) -> Int {
        thresholdStore.threshold(for: item.id)
    }

    func isLowStock(_ item: InventoryCSVItem) -> Bool {
        thresholdStore.isLowStock(quantity: item.quantityOnHand, partID: item.id)
    }

    // MARK: - Sheet Presentation

    func showThresholdSheet(for item: InventoryCSVItem) {
        thresholdSheetItem = item
    }
}

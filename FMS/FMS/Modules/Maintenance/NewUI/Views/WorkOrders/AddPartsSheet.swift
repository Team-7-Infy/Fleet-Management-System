import SwiftUI

struct AddPartsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let dependencies: AppDependencyContainer
    let usedParts: [PartItem]
    var vehicleType: String?
    let onAddPart: (SparePart, Int) -> Void
    
    @State private var allParts: [SparePart] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var alertMessage: String?
    @State private var showAlert = false
    
    var filteredParts: [SparePart] {
        allParts.map { part in
            let usedQuantity = usedParts.first(where: { $0.id == part.id.uuidString })?.quantity ?? 0
            return InventoryItem(
                id: part.id,
                partname: part.partname,
                cost: part.cost,
                quantityOnHand: max(0, (part.quantityOnHand ?? 0) - usedQuantity),
                vehicletype: part.vehicletype
            )
        }.filter { part in
            let matchesVehicle = vehicleType == nil || part.vehicletype == nil || part.vehicletype?.lowercased() == vehicleType?.lowercased()
            let matchesSearch = searchText.isEmpty || part.name.localizedCaseInsensitiveContains(searchText) || part.id.uuidString.localizedCaseInsensitiveContains(searchText)
            return matchesVehicle && matchesSearch
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                Text("Add Parts")
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.black)
                        .frame(width: 36, height: 36)
                        .background(Color.white)
                        .clipShape(Circle())
                }
            }
            .padding(24)
            
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.gray)
                TextField("Search for spare parts", text: $searchText)
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 30))
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            
            // Categories removed
            
            // Parts List
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(filteredParts) { part in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(part.name)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Color.black)
                                Text("₹\(NSDecimalNumber(decimal: part.unitPrice).intValue)/part")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.gray)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("\(part.currentQuantity) in stock")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(part.currentQuantity > 0 ? Color.gray : Color.red)
                                
                                Button(action: {
                                    onAddPart(part, 1)
                                    dismiss() 
                                }) {
                                    Text("Add")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(part.currentQuantity > 0 ? Color.blue : Color.gray)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 6)
                                        .background(part.currentQuantity > 0 ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                                .disabled(part.currentQuantity == 0)
                            }
                        }
                        .padding(.vertical, 16)
                        
                        if part != filteredParts.last {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 24)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white)
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .overlay {
                    if isLoading {
                        ProgressView("Loading inventory...")
                    }
                }
            }
        }
        .background(AppColor.background.ignoresSafeArea())
        .task {
            isLoading = true
            do {
                allParts = try await dependencies.workOrderService.fetchInventory()
            } catch {
                alertMessage = "Failed to load inventory: \(error.localizedDescription)"
                showAlert = true
            }
            isLoading = false
        }
        .alert("Inventory", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage ?? "An error occurred.")
        }
    }
}

#Preview {
    AddPartsSheet(dependencies: .mock(), usedParts: [], vehicleType: "Truck") { _, _ in }
}

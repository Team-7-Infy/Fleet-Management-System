import SwiftUI

// MARK: - Inventory View
struct InventoryView: View {
    @StateObject private var viewModel = InventoryViewModel()

    var body: some View {
        List {
            // Category filter
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(VehicleCategory.allCases) { category in
                            categoryChip(category)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            // Inventory rows
            if viewModel.filteredItems.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No parts found",
                        systemImage: "wrench.and.screwdriver",
                        description: Text("Try adjusting your search or category filter.")
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            } else {
                Section {
                    ForEach(viewModel.filteredItems) { item in
                        NativeInventoryRow(
                            item: item,
                            isLowStock: viewModel.isLowStock(item),
                            threshold: viewModel.threshold(for: item),
                            onSetThreshold: { viewModel.showThresholdSheet(for: item) }
                        )
                        .listRowBackground(FleetPalette.surface)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                viewModel.showThresholdSheet(for: item)
                            } label: {
                                Label("Threshold", systemImage: "gauge.badge.plus")
                            }
                            .tint(viewModel.isLowStock(item) ? FleetPalette.danger : FleetPalette.accent)
                        }
                    }
                }
            }
        }
        .background(AppColor.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(item: $viewModel.thresholdSheetItem) { item in
            InventoryThresholdSheet(item: item, store: viewModel.thresholdStore)
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
                .presentationBackground(.clear)
        }
    }

    // MARK: - Category Chip
    private func categoryChip(_ category: VehicleCategory) -> some View {
        let isSelected = viewModel.selectedCategory == category
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                viewModel.selectedCategory = category
            }
        } label: {
            Text(category.rawValue)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? FleetPalette.surface : FleetPalette.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    isSelected
                        ? FleetPalette.accent
                        : FleetPalette.tertiary.opacity(0.15),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Native Inventory Row
struct NativeInventoryRow: View {
    let item: InventoryCSVItem
    let isLowStock: Bool
    let threshold: Int
    let onSetThreshold: () -> Void

    private var iconForPart: String {
        let name = item.partname.lowercased()
        if name.contains("filter")                                          { return "camera.filters" }
        if name.contains("oil") || name.contains("fluid") || name.contains("coolant") { return "drop.fill" }
        if name.contains("brake") || name.contains("pad")                   { return "circle.dashed" }
        if name.contains("tire") || name.contains("wheel")                  { return "circle.circle.fill" }
        if name.contains("battery")                                         { return "minus.plus.batteryblock.fill" }
        if name.contains("light") || name.contains("bulb")                  { return "lightbulb.fill" }
        if name.contains("engine") || name.contains("motor")                { return "engine.combustion.fill" }
        if name.contains("belt")                                            { return "link" }
        if name.contains("sensor")                                          { return "sensor.tag.radiowaves.forward" }
        if name.contains("wiper")                                           { return "cloud.rain.fill" }
        if name.contains("spark") || name.contains("plug")                  { return "bolt.fill" }
        if name.contains("gear") || name.contains("clutch")                 { return "gearshape.fill" }
        if name.contains("radiator") || name.contains("cooling")            { return "snowflake" }
        let fallbacks = ["nut.fill", "wrench.adjustable.fill", "hammer.fill", "screwdriver.fill", "shippingbox.fill"]
        return fallbacks[abs(item.partname.hashValue) % fallbacks.count]
    }

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            Image(systemName: iconForPart)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(isLowStock ? FleetPalette.danger : FleetPalette.accent)
                .frame(width: 40, height: 40)
                .background(
                    (isLowStock ? FleetPalette.danger : FleetPalette.accent).opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )

            // Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.partname)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(FleetPalette.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    StatusPill(
                        text: isLowStock ? "Low Stock" : "In Stock",
                        color: isLowStock ? FleetPalette.danger : FleetPalette.success,
                        dotSize: 6
                    )
                }

                HStack(spacing: 4) {
                    Text(item.vehicletype)
                    Text("•")
                    Text(item.partcode)
                }
                .font(.caption)
                .foregroundStyle(FleetPalette.textSecondary)

                HStack {
                    Text(item.priceFormatted)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(FleetPalette.textSecondary)
                    Text("/ part")
                        .font(.caption2)
                        .foregroundStyle(FleetPalette.textTertiary)

                    Spacer()

                    Text("Qty \(item.quantityOnHand)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(isLowStock ? FleetPalette.danger : FleetPalette.success)
                }
            }
        }
        .padding(.vertical, 10)
        .contextMenu {
            Button {
                onSetThreshold()
            } label: {
                Label("Set Threshold", systemImage: "gauge.badge.plus")
            }
        }
    }
}

#Preview {
    NavigationStack {
        InventoryView()
    }
}

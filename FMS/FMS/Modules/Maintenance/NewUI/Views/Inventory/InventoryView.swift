import SwiftUI

// MARK: - Inventory View
struct InventoryView: View {
    @StateObject private var viewModel = InventoryViewModel()
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // ── Liquid Glass Search Bar ──────────────────────
                liquidGlassSearchBar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)

                // ── Vehicle Category Chips ───────────────────────
                categoryChips
                    .padding(.bottom, 16)

                // ── Inventory List ───────────────────────────────
                inventoryList
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
            }
        }
        .background(AppColor.background.ignoresSafeArea())
        .navigationTitle("Inventory")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onTapGesture { isSearchFocused = false }
        // ── Threshold Sheet ──────────────────────────────────────
        .sheet(item: $viewModel.thresholdSheetItem) { item in
            InventoryThresholdSheet(item: item, store: viewModel.thresholdStore)
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden) // we draw our own handle
                .presentationBackground(.clear)
        }
    }

    // MARK: - Liquid Glass Search Bar
    private var liquidGlassSearchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)

            TextField("Search for spare parts", text: $viewModel.searchText)
                .focused($isSearchFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(AppColor.textPrimary)

            if !viewModel.searchText.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.searchText = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    // MARK: - Category Chips (Liquid Glass)
    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(VehicleCategory.allCases) { category in
                        categoryChip(category)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
        }
        .scrollClipDisabled()
        .padding(.vertical, 4)
    }

    private func categoryChip(_ category: VehicleCategory) -> some View {
        let isSelected = viewModel.selectedCategory == category
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                viewModel.selectedCategory = category
            }
        } label: {
            Text(category.rawValue)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : AppColor.textPrimary)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                // Solid blue fill sits behind the glass layer for selected state
                .background(
                    Capsule()
                        .fill(isSelected ? AppColor.brand : Color.clear)
                )
        }
        .glassEffect(
            isSelected ? .regular : .regular.interactive(),
            in: .capsule
        )
        .tint(isSelected ? AppColor.brand : .clear)
    }

    // MARK: - Inventory List
    @ViewBuilder
    private var inventoryList: some View {
        let items = viewModel.filteredItems
        if items.isEmpty {
            emptyState
        } else {
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    InventoryRow(
                        item: item,
                        isLowStock: viewModel.isLowStock(item),
                        threshold: viewModel.threshold(for: item),
                        isLast: index == items.count - 1,
                        onSetThreshold: {
                            viewModel.showThresholdSheet(for: item)
                        }
                    )
                    .id("\(item.id)-\(viewModel.threshold(for: item))-\(viewModel.isLowStock(item))")
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)
                            .stroke(Color.gray.opacity(0.09), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 48))
                .foregroundStyle(AppColor.brand.opacity(0.4))

            Text("No parts found")
                .font(.headline)
                .foregroundStyle(AppColor.textPrimary)

            Text("Try adjusting your search or filter.")
                .font(.subheadline)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

#Preview {
    InventoryView()
}

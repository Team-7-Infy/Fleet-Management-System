import SwiftUI

// MARK: - Inventory View
struct InventoryView: View {
    @StateObject private var viewModel = InventoryViewModel()
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // ── Custom Header ────────────────────────────────
            headerView
            VStack(spacing: 16) {
                searchBar
                categoryChips
            }
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // ── Inventory List ───────────────────────────────
                    inventoryList
                        .padding(.top, 16)
                        .padding(.horizontal, 0) // Rows have their own padding
                        .padding(.bottom, 100)
                }
            }
        }
        .background(Color(hex: 0xF4F5F9).ignoresSafeArea())
        .navigationBarHidden(true)
        .onTapGesture { isSearchFocused = false }
        // ── Threshold Sheet ──────────────────────────────────────
        .sheet(item: $viewModel.thresholdSheetItem) { item in
            InventoryThresholdSheet(item: item, store: viewModel.thresholdStore)
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden) // we draw our own handle
                .presentationBackground(.clear)
        }
    }

    // MARK: - Custom Header
    private var headerView: some View {
        HStack {
            Text("Inventory")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.black)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 16)
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.gray)

            TextField("Search for spare parts", text: $viewModel.searchText)
                .focused($isSearchFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 16, weight: .medium))

            if !viewModel.searchText.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.searchText = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.gray.opacity(0.8))
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(hex: 0xE8EAED))
        .clipShape(Capsule())
        .padding(.horizontal, 20)
    }

    // MARK: - Category Chips
    private var categoryChips: some View {
        HStack(spacing: 0) {
            ForEach(VehicleCategory.allCases) { category in
                categoryChip(category)
            }
        }
        .padding(4)
        .background(Color(hex: 0xE8EAED))
        .clipShape(Capsule())
        .padding(.horizontal, 20)
    }

    private func categoryChip(_ category: VehicleCategory) -> some View {
        let isSelected = viewModel.selectedCategory == category
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                viewModel.selectedCategory = category
            }
        } label: {
            Text(category.rawValue)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? Color.black : Color.gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? Color.white : Color.clear)
                .clipShape(Capsule())
                .shadow(color: isSelected ? Color.black.opacity(0.04) : .clear, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Inventory List
    @ViewBuilder
    private var inventoryList: some View {
        let items = viewModel.filteredItems
        if items.isEmpty {
            emptyState
        } else {
            LazyVStack(spacing: 8) {
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
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 48))
                .foregroundStyle(AppColor.brand.opacity(0.4))

            Text("No parts found")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(AppColor.textPrimary)

            Text("Try adjusting your search or filter.")
                .font(.system(.subheadline, design: .rounded))
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

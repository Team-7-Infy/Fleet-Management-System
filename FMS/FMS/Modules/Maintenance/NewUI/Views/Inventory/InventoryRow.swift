import SwiftUI

// MARK: - Inventory Row
struct InventoryRow: View {
    let item: InventoryCSVItem
    let isLowStock: Bool
    let threshold: Int
    let isLast: Bool
    let onSetThreshold: () -> Void

    @State private var offset: CGFloat = 0
    @State private var isSwiped = false
    @GestureState private var isDragging = false

    private let buttonWidth: CGFloat = 90

    var body: some View {
        ZStack(alignment: .trailing) {
            // ── Background Action Button ──────────────────────
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    offset = 0
                    isSwiped = false
                }
                onSetThreshold()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "gauge.badge.plus")
                        .font(.title3)
                    Text("Threshold")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(width: buttonWidth, height: 72)
                .background(isLowStock ? AppColor.warning : AppColor.brand)
            }
            .opacity(offset < 0 ? 1 : 0)

            // ── Main Content Row ──────────────────────────────
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 12) {
                    // Left: Part Name + Subtitle
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.partname)
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundStyle(AppColor.textPrimary)

                        HStack(spacing: 4) {
                            Text(item.vehicletype)
                                .foregroundStyle(AppColor.textSecondary)
                            Text("•")
                                .foregroundStyle(AppColor.textSecondary.opacity(0.5))
                            Text(item.partcode)
                                .foregroundStyle(AppColor.textSecondary)
                        }
                        .font(.subheadline)
                    }

                    Spacer()

                    // Right: Stock + Price
                    VStack(alignment: .trailing, spacing: 3) {
                        HStack(spacing: 4) {
                            if isLowStock {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(AppColor.warning)
                                    .transition(.scale.combined(with: .opacity))
                            }
                            Text(item.stockLabel)
                                .font(.system(size: 14))
                                .foregroundStyle(isLowStock ? AppColor.warning : AppColor.textSecondary)
                        }
                        .animation(.spring(response: 0.3), value: isLowStock)

                        Text(item.priceFormatted)
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(AppColor.brand)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white) // Solid background covers button when closed
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 15, coordinateSpace: .local)
                        .updating($isDragging) { _, state, _ in
                            state = true
                        }
                        .onChanged { value in
                            let dragAmount = value.translation.width
                            if isSwiped {
                                // Swiping starting from opened position
                                offset = dragAmount - buttonWidth
                            } else {
                                // Only swipe left (negative offsets)
                                offset = min(0, dragAmount)
                            }
                        }
                        .onEnded { value in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                // Snap open if dragged left past threshold
                                if value.predictedEndTranslation.width < -buttonWidth / 2 {
                                    offset = -buttonWidth
                                    isSwiped = true
                                } else {
                                    offset = 0
                                    isSwiped = false
                                }
                            }
                        }
                )
                // ── Context Menu (Hold row to show option) ──────
                .contextMenu {
                    Button {
                        onSetThreshold()
                    } label: {
                        Label("Set Threshold", systemImage: "gauge.badge.plus")
                    }
                }

                if !isLast {
                    Divider()
                        .padding(.horizontal, 16)
                        .offset(x: offset)
                }
            }
        }
    }
}

import SwiftUI

// MARK: - Inventory Threshold Sheet
struct InventoryThresholdSheet: View {

    let item: InventoryCSVItem
    @ObservedObject var store: ThresholdStore

    @Environment(\.dismiss) private var dismiss

    /// Draft value the user is editing — initialised from the store.
    @State private var draft: Int = ThresholdStore.defaultThreshold
    @State private var hasAppeared = false

    // MARK: - Derived

    private var isCurrentlyLow: Bool {
        item.quantityOnHand < draft
    }

    private var statusText: String {
        if item.quantityOnHand == 0 {
            return "Out of stock"
        } else if isCurrentlyLow {
            return "Below threshold"
        } else {
            return "Stock is sufficient"
        }
    }

    private var statusColor: Color {
        isCurrentlyLow ? AppColor.warning : .green
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                // ── Handle ────────────────────────────────────────────────
                Capsule()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 36, height: 5)
                    .padding(.top, 20)
                    .padding(.bottom, 20)

                // ── Header ────────────────────────────────────────────────
                partHeader
                    .padding(.horizontal, 24)

                Divider()
                    .padding(.vertical, 24)

                // ── Threshold Control ─────────────────────────────────────
                thresholdControl
                    .padding(.horizontal, 24)

                // ── Current Stock Info ────────────────────────────────────
                stockInfo
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 18)

                // Spacer(minLength: 24)

                // ── Save Button ───────────────────────────────────────────
                saveButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
            }
            .frame(maxHeight: .infinity, alignment: .top)

            // ── Close Button ──────────────────────────────────────────
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .glassEffect(.clear.interactive(), in: .capsule)
            .padding(.top, 34)
            .padding(.trailing, 24)
            .accessibilityLabel("Close")
        }
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 24,
                bottomLeadingRadius: 12, // ONLY bottom radius changed/set here
                bottomTrailingRadius: 12,
                topTrailingRadius: 24,
                style: .continuous
            )
            .fill(AppColor.background)
        )
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 24,
                bottomLeadingRadius: 12,
                bottomTrailingRadius: 12,
                topTrailingRadius: 24,
                style: .continuous
            )
        )
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            draft = store.threshold(for: item.id)
        }
    }

    // MARK: - Part Header

    private var partHeader: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.partname)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(AppColor.textPrimary)

                HStack(spacing: 4) {
                    Text(item.vehicletype)
                    Text("•")
                    Text(item.partcode)
                }
                .font(.subheadline)
                .foregroundStyle(AppColor.textSecondary)
            }
            Spacer()
        }
    }

    private var thresholdControl: some View {
        VStack(spacing: 16) {
            Text("Minimum Stock Threshold")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 6) {
                HStack(spacing: 32) {
                    // ── Decrement ─────────────────────
                    stepperButton(
                        systemName: "minus",
                        isDisabled: draft <= 0
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            draft = max(0, draft - 1)
                        }
                    }

                    // ── Value ─────────────────────────
                    Text("\(draft)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColor.textPrimary)
                        .contentTransition(.numericText(value: Double(draft)))
                        .animation(.spring(response: 0.3), value: draft)
                        .frame(minWidth: 80)

                    // ── Increment ─────────────────────
                    stepperButton(systemName: "plus", isDisabled: false) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            draft += 1
                        }
                    }
                }

                // ── Units ─────────────────────────
                Text("units")
                    .font(.caption)
                    .foregroundStyle(AppColor.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func stepperButton(
        systemName: String,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title2.weight(.semibold))
                .foregroundStyle(isDisabled ? Color.secondary.opacity(0.4) : AppColor.brand)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(isDisabled
                              ? Color.secondary.opacity(0.08)
                              : AppColor.brand.opacity(0.1))
                )
        }
        .disabled(isDisabled)
        .accessibilityLabel(systemName == "minus" ? "Decrease threshold" : "Increase threshold")
    }

    // MARK: - Stock Info

    private var stockInfo: some View {
        HStack(spacing: 10) {
            Image(systemName: isCurrentlyLow ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(statusColor)
                .symbolEffect(.pulse, isActive: isCurrentlyLow)

            VStack(alignment: .leading, spacing: 2) {
                Text("Current stock: \(item.quantityOnHand) units")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColor.textPrimary)

                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(statusColor)
                    .animation(.easeInOut(duration: 0.2), value: isCurrentlyLow)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous)
                .fill(statusColor.opacity(0.08))
        )
        .animation(.easeInOut(duration: 0.25), value: isCurrentlyLow)
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            store.setThreshold(draft, for: item.id)
            dismiss()
        } label: {
            Text("Save Threshold")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)
                        .fill(AppColor.brand)
                )
        }
        .accessibilityLabel("Save threshold of \(draft) units for \(item.partname)")
    }
}

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
    
    private var iconForPart: String {
        let name = item.partname.lowercased()
        if name.contains("filter") { return "camera.filters" }
        if name.contains("oil") || name.contains("fluid") || name.contains("coolant") { return "drop.fill" }
        if name.contains("brake") || name.contains("pad") || name.contains("shoe") { return "circle.dashed" }
        if name.contains("tire") || name.contains("wheel") { return "circle.circle.fill" }
        if name.contains("battery") { return "minus.plus.batteryblock.fill" }
        if name.contains("light") || name.contains("bulb") { return "lightbulb.fill" }
        if name.contains("engine") || name.contains("motor") { return "engine.combustion.fill" }
        if name.contains("belt") { return "link" }
        if name.contains("sensor") { return "sensor.tag.radiowaves.forward" }
        if name.contains("mirror") || name.contains("glass") { return "rectangle.dashed" }
        if name.contains("wiper") { return "cloud.rain.fill" }
        if name.contains("spark") || name.contains("plug") { return "bolt.fill" }
        if name.contains("suspension") || name.contains("shock") { return "car.side.fill" }
        if name.contains("cable") || name.contains("wire") { return "cable.connector.horizontal" }
        if name.contains("pump") { return "humidity.fill" }
        if name.contains("gear") || name.contains("clutch") || name.contains("transmission") { return "gearshape.fill" }
        if name.contains("hose") || name.contains("pipe") { return "point.topleft.down.curvedto.point.bottomright.up" }
        if name.contains("valve") { return "dial.min.fill" }
        if name.contains("radiator") || name.contains("cooling") { return "snowflake" }
        if name.contains("bearing") { return "circle.nested" }
        
        let fallbacks = ["nut.fill", "wrench.adjustable.fill", "hammer.fill", "screwdriver.fill", "shippingbox.fill", "tray.fill", "cylinder.split.1x2"]
        let index = abs(name.hashValue) % fallbacks.count
        return fallbacks[index]
    }

    @Environment(\.colorScheme) var colorScheme

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
                .frame(width: buttonWidth)
                .frame(maxHeight: .infinity)
                .background(isLowStock ? Color.red : AppColor.brand)
            }
            .opacity(offset < 0 ? 1 : 0)
            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous))

            // ── Main Content Row ──────────────────────────────
            HStack(alignment: .center, spacing: 14) {
                // ICON
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColor.brand.opacity(0.12))
                    Image(systemName: iconForPart)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppColor.brand)
                }
                .frame(width: 48, height: 48)
                
                // MIDDLE TEXT: Name and Vehicle type
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.partname)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        
                    HStack(spacing: 4) {
                        Text(item.vehicletype.capitalized)
                        Text("•")
                        Text(item.partcode)
                    }
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
                }
                
                Spacer(minLength: 8)
                
                // RIGHT SIDE: Price and Pill
                VStack(alignment: .trailing, spacing: 6) {
                    Text(item.priceFormatted)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary)
                    
                    HStack(spacing: 4) {
                        if isLowStock {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(AppColor.destructive)
                        }
                        
                        Text("\(item.quantityOnHand) left")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(isLowStock ? AppColor.destructive : AppColor.success)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(isLowStock ? AppColor.destructive.opacity(0.12) : AppColor.success.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                
                // FAR RIGHT: Chevron
                Image(systemName: "chevron.left.2")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.secondary.opacity(0.5))
                    .padding(.leading, 4)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(GlassPanel(hasBorder: true) { Color.clear })
            .offset(x: offset)
            .gesture(
                DragGesture(minimumDistance: 15, coordinateSpace: .local)
                    .updating($isDragging) { _, state, _ in
                        state = true
                    }
                    .onChanged { value in
                        let dragAmount = value.translation.width
                        if isSwiped {
                            offset = dragAmount - buttonWidth
                        } else {
                            offset = min(0, dragAmount)
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
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
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 16)
    }
}

import SwiftUI

struct OnHoldWorkOrderCard: View {
    let onHoldOrder: OnHoldWorkOrder
    var action: (() -> Void)?
    
    var body: some View {
        Button {
            action?()
        } label: {
            HStack(alignment: .center, spacing: 12) {
                let vehicleDisplay = onHoldOrder.vehicle?.registrationNumber ?? onHoldOrder.vehicle?.name ?? onHoldOrder.workOrder.vehicleName
                
                Image(systemName: onHoldOrder.vehicle?.sfSymbolName ?? FleetIcon.car)
                    .font(.title3)
                    .foregroundStyle(AppColor.brand)
                    .frame(width: 44, height: 28)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(vehicleDisplay)
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColor.textPrimary)
                    
                    Text(onHoldOrder.workOrder.title)
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColor.textSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "pause.fill")
                        .font(.headline)
                        .foregroundStyle(Color.orange.opacity(0.7))
                }
            }
            .padding(.vertical, AppSpacing.medium)
            .padding(.horizontal, AppSpacing.large)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium))
            .shadow(color: AppColor.textPrimary.opacity(0.06), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

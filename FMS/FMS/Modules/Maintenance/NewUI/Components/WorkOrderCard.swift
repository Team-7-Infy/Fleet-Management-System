import SwiftUI

struct WorkOrderCard: View {
    let workOrder: WorkOrder
    var action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                        Text(workOrder.id.uuidString.prefix(8).uppercased())
                            .font(AppTypography.headline)
                        Text("\(workOrder.vehicleName) - \(workOrder.title)")
                            .font(AppTypography.callout)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                    Spacer()
                    MPStatusBadge(status: workOrder.status)
                }
                PriorityBadge(priority: workOrder.priority)
                Text("Due: \(workOrder.dueDate.formatted(.dateTime.month(.abbreviated).day().year()))")
                    .font(AppTypography.footnote)
                    .foregroundStyle(AppColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .appCardStyle()
        }
        .buttonStyle(CardButtonStyle())
        .accessibilityLabel(AccessibilityText.workOrder(workOrder.id.uuidString, status: workOrder.status.title))
    }
}

#Preview {
    WorkOrderCard(workOrder: PreviewData.workOrders[0])
        .padding()
}

import SwiftUI

struct VehicleCard: View {
    let vehicle: Vehicle
    var action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: AppSpacing.medium) {
                Image(systemName: vehicle.sfSymbolName)
                    .font(.title2)
                    .foregroundStyle(AppColor.brand)
                    .frame(width: 64, height: 64)
                    .background(AppColor.secondaryBackground, in: RoundedRectangle(cornerRadius: AppCornerRadius.small))

                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text(vehicle.name)
                        .font(AppTypography.headline)
                    Text(vehicle.registrationNumber)
                        .font(AppTypography.footnote)
                        .foregroundStyle(AppColor.textSecondary)
                    Text(vehicle.status.rawValue.capitalized)
                        .font(AppTypography.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(AppColor.secondaryBackground, in: Capsule())
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .appCardStyle()
        }
        .buttonStyle(CardButtonStyle())
        .accessibilityLabel("\(vehicle.name), \(vehicle.status.rawValue.capitalized)")
    }
}

#Preview {
    VehicleCard(vehicle: PreviewData.vehicles[0])
        .padding()
}

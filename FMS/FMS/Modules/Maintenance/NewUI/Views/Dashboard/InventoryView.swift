import SwiftUI

struct InventoryView: View {
    var body: some View {
        VStack {
            Spacer()
            Image(systemName: "shippingbox.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundStyle(AppColor.brand)
                .padding(.bottom, 16)
            
            Text("Inventory")
                .font(AppTypography.title)
                .foregroundStyle(AppColor.textPrimary)
            
            Text("This is a dummy screen for inventory management.")
                .font(AppTypography.callout)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 8)
                
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.background.ignoresSafeArea())
    }
}

#Preview {
    InventoryView()
}

import SwiftUI

struct ReusableNavigationBar<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack {
            Text(title)
                .font(AppTypography.title)
            Spacer()
            trailing
        }
        .padding(.horizontal, AppSpacing.large)
        .padding(.vertical, AppSpacing.small)
    }
}

#Preview {
    ReusableNavigationBar(title: "Dashboard") {
        Button("Edit") { }
    }
}

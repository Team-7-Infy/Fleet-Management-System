import SwiftUI

struct MPSearchBar: View {
    @Binding var text: String
    var placeholder = "Search"

    var body: some View {
        HStack(spacing: AppSpacing.small) {
            Image(systemName: AppIcon.search)
                .foregroundStyle(AppColor.textSecondary)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
        }
        .padding(AppSpacing.medium)
        .background(AppColor.secondaryBackground, in: RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous))
    }
}

#Preview {
    @Previewable @State var text = ""
    MPSearchBar(text: $text)
        .padding()
}

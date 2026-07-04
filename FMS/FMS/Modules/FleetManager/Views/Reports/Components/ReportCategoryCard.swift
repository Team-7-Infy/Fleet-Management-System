import SwiftUI

struct ReportCategoryCard<Content: View>: View {
    let title: String
    let systemImage: String
    let tint: Color
    @ViewBuilder let content: Content

    var body: some View {
        GlassPanel(hasBorder: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    IconBubble(systemImage: systemImage, tint: tint)
                    Text(title)
                        .font(.headline).bold()
                        .foregroundStyle(FleetPalette.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption).bold()
                        .foregroundStyle(FleetPalette.textSecondary)
                }

                content
            }
        }
    }
}

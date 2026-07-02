//
//  GlassPanel.swift
//  FMS
//
//  Created by Veer on 26/06/26.
//


import SwiftUI
struct GlassPanel<Content: View>: View {
    private let content: Content
    private let hasBorder: Bool

    init(hasBorder: Bool = true, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.hasBorder = hasBorder
    }

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FleetPalette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                if hasBorder {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(FleetPalette.tertiary.opacity(0.55), lineWidth: 1)
                }
            }
            .shadow(
                color: hasBorder ? FleetPalette.accent.opacity(0.10) : Color.black.opacity(0.03),
                radius: hasBorder ? 16 : 15,
                x: 0,
                y: hasBorder ? 9 : 5
            )
    }
}

//
//  GlassPanel.swift
//  FMS
//
//  Created by Veer on 26/06/26.
//


import SwiftUI
struct GlassPanel<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FleetPalette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(FleetPalette.tertiary.opacity(0.55), lineWidth: 1)
            }
            .shadow(color: FleetPalette.accent.opacity(0.10), radius: 16, x: 0, y: 9)
    }
}

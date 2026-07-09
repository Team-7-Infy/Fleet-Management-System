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
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.gray, lineWidth: 1)
            }
    }
}

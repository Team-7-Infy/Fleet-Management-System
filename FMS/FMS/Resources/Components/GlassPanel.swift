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

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(colorScheme == .dark ? Color(white: 0.15) : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.04), radius: 12, x: 0, y: 6)
            .overlay(
                Group {
                    if hasBorder {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.gray.opacity(colorScheme == .dark ? 0.3 : 0.2), lineWidth: 1)
                    }
                }
            )
    }
}

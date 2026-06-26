//
//  ViewModifiers.swift
//  FMS
//
//  Created by Veer on 26/06/26.
//

import SwiftUI

extension View {
    func fleetScreenBackground() -> some View {
        background(FleetPalette.background.ignoresSafeArea())
    }

    func fleetField() -> some View {
        modifier(FleetFieldModifier())
    }
}



struct FleetFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(FleetPalette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(FleetPalette.tertiary.opacity(0.45), lineWidth: 1)
            }
    }
}

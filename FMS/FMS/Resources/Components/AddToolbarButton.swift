//
//  AddToolbarButton.swift
//  FMS
//
//  Created by Veer on 26/06/26.
//

import SwiftUI

struct AddToolbarButton: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(FleetPalette.accent, in: Circle())
                .shadow(color: FleetPalette.accent.opacity(0.22), radius: 10, x: 0, y: 5)
        }
        .accessibilityLabel(title)
    }
}

//
//  FleetSearchBar.swift
//  FMS
//
//  Created by Veer on 26/06/26.
//

import SwiftUI

struct FleetSearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(FleetPalette.textSecondary)

            TextField("Search", text: $text)
                .textInputAutocapitalization(.never)

            if text.isEmpty == false {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(FleetPalette.textSecondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(FleetPalette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(FleetPalette.tertiary.opacity(0.45), lineWidth: 1)
        }
    }
}

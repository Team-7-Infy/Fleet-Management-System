//
//  InfoRow.swift
//  FMS
//
//  Created by Veer on 26/06/26.
//



import SwiftUI
struct InfoRow: View {
    var title: String
    var value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(FleetPalette.textSecondary)
                .frame(width: 112, alignment: .leading)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(FleetPalette.textPrimary)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

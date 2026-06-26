//
//  DashboardActionButton.swift
//  FMS
//
//  Created by Veer on 26/06/26.
//

import SwiftUI

struct DashboardActionButton: View {
    var title: String
    var detail: String
    var systemImage: String
    var tint: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                IconBubble(systemImage: systemImage, tint: tint)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(FleetPalette.textPrimary)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(FleetPalette.textSecondary)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FleetPalette.textSecondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FleetPalette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(FleetPalette.tertiary.opacity(0.45), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

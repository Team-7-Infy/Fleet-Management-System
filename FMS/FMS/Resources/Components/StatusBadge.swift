//
//  StatusPill.swift
//  FMS
//
//  Created by Veer on 26/06/26.
//
import SwiftUI

struct StatusPill: View {
    var text: String
    var color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(color.opacity(0.12), in: Capsule())
            .foregroundStyle(color)
    }
}

struct StatusDot: View {
    var text: String
    var color: Color
    var size: CGFloat = 14

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.88), lineWidth: max(1.5, size * 0.12))
                }
                .shadow(color: color.opacity(0.24), radius: 3, y: 1)

            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(FleetPalette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .padding(.leading, 10)
        .padding(.trailing, 12)
        .padding(.vertical, 7)
        .background(Color.secondary.opacity(0.09), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

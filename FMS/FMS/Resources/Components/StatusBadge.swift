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
    var dotSize: CGFloat = 10

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(color)
                .frame(width: dotSize, height: dotSize)

            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.black)
                .lineLimit(1)
        }
        .padding(.leading, 10)
        .padding(.trailing, 12)
        .padding(.vertical, 6)
        .background(Color("FleetBackground"), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
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

            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .padding(.leading, 10)
        .padding(.trailing, 12)
        .padding(.vertical, 7)
        .background(Color("FleetBackground"), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

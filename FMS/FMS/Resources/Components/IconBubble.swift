//
//  IconBubble.swift
//  FMS
//
//  Created by Veer on 26/06/26.
//
import SwiftUI

struct IconBubble: View {
    var systemImage: String
    var tint: Color

    var body: some View {
        let isYellow = tint == FleetPalette.warning
        let displayTint = isYellow ? Color(hex: 0xB58A00) : tint
        
        Image(systemName: systemImage)
            .font(.headline.weight(.semibold))
            .foregroundStyle(displayTint)
            .frame(width: 48, height: 48)
            .background((isYellow ? FleetPalette.warning : tint).opacity(0.12), in: Circle())
    }
}

struct VehicleAssetImage: View {
    var vehicle: Vehicle?
    var assetName: String?
    var width: CGFloat = 64
    var height: CGFloat = 52
    var cornerRadius: CGFloat = 14

    var body: some View {
        Image(assetName ?? vehicle?.assetImageName ?? "Car")
            .resizable()
            .scaledToFill()
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
            .accessibilityHidden(true)
    }
}

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
        Image(systemName: systemImage)
            .font(.headline.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: 48, height: 48)
            .background(tint.opacity(0.12), in: Circle())
    }
}

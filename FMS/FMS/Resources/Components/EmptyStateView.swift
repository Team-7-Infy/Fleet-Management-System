//
//  EmptyStateView.swift
//  FMS
//
//  Created by Veer on 26/06/26.
//


import SwiftUI


struct EmptyStateView: View {
    var title: String
    var message: String
    var systemImage: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(FleetPalette.primary)

            Text(title)
                .font(.headline)
                .foregroundStyle(FleetPalette.textPrimary)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(FleetPalette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}
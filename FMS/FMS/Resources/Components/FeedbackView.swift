//
//  FeedbackView.swift
//  FMS
//
//  Created by Veer on 26/06/26.
//


import SwiftUI

struct FeedbackView: View {
    var success: String?
    var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let success {
                Label(success, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(FleetPalette.success)
            }

            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(FleetPalette.danger)
            }
        }
        .font(.subheadline.weight(.semibold))
    }
}
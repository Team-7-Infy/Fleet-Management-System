//
//  DashboardSectionTitle.swift
//  FMS
//
//  Created by Veer on 26/06/26.
//

import SwiftUI
struct DashboardSectionTitle: View {
    var title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(FleetPalette.textSecondary)
            .tracking(0)
            .padding(.horizontal, 4)
    }
}

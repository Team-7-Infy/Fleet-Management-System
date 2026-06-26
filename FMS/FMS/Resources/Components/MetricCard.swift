//
//  DashboardMetricCard.swift
//  FMS
//
//  Created by Veer on 26/06/26.
//
import SwiftUI


struct DashboardMetricCard: View {
    var title: String
    var systemImage: String
    var tint: Color
    var metrics: [(String, String)]

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(title, systemImage: systemImage)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(FleetPalette.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(FleetPalette.textSecondary)
                }

                ForEach(metrics, id: \.0) { metric in
                    HStack {
                        Text(metric.0)
                            .font(.caption)
                            .foregroundStyle(FleetPalette.textSecondary)
                        Spacer()
                        Text(metric.1)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(tint)
                    }
                }
            }
        }
    }
}

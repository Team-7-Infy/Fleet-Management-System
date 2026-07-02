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
        GlassPanel(hasBorder: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    IconBubble(systemImage: systemImage, tint: tint)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(FleetPalette.textPrimary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(FleetPalette.textSecondary)
                }

                VStack(spacing: 10) {
                    ForEach(metrics, id: \.0) { metric in
                        HStack {
                            Text(metric.0)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(FleetPalette.textSecondary)
                            Spacer()
                            Text(metric.1)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(tint)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }
}

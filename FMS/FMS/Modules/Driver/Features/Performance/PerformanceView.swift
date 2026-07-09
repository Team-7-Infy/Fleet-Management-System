//
//  PerformanceView.swift
//  FMSD
//
//  Created by Dev Jain on 24/06/26.
//


import SwiftUI

struct PerformanceView: View {
    @StateObject private var viewModel: PerformanceViewModel

    init(driverId: UUID, services: AppServices) {
        _viewModel = StateObject(wrappedValue: PerformanceViewModel(
            tripService: services.tripService,
            userManagementService: services.userManagementService,
            driverId: driverId
        ))
    }

    var body: some View {
        ZStack {
            AppColor.background.edgesIgnoringSafeArea(.all)

            if viewModel.isLoading {
                ProgressView("Calculating Metrics...")
            } else if let metrics = viewModel.metrics {
                ScrollView {
                    VStack(spacing: 20) {

                        // Hero Section: Safety Score
                        VStack {
                            Text("Overall Safety Score")
                                .font(.headline)
                                .foregroundColor(.gray)

                            let isNew = metrics.tripsCompleted == 0
                            let scoreColor = isNew ? Color.gray.opacity(0.3) : viewModel.scoreColor(for: metrics.safetyScore)

                            ZStack {
                                Circle()
                                    .stroke(lineWidth: 15)
                                    .opacity(0.2)
                                    .foregroundColor(scoreColor)

                                Circle()
                                    .trim(from: 0.0, to: isNew ? 0.0 : CGFloat(metrics.safetyScore) / 100.0)
                                    .stroke(style: StrokeStyle(lineWidth: 15, lineCap: .round, lineJoin: .round))
                                    .foregroundColor(scoreColor)
                                    .rotationEffect(Angle(degrees: 270.0))
                                    .animation(.easeInOut(duration: 1.5), value: metrics.safetyScore)

                                VStack {
                                    Text(isNew ? "--" : "\(metrics.safetyScore)")
                                        .font(.system(size: 50, weight: .bold, design: .rounded))
                                    Text(isNew ? "No trip history" : "Out of 100")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            .frame(width: 180, height: 180)
                            .padding()
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(AppColor.surface)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .padding(.horizontal)

                        // Grid Section: Core KPIs
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            KPIBox(title: "Trips Completed", value: "\(metrics.tripsCompleted)", icon: "checkmark.circle.fill", color: .blue)
                            KPIBox(title: "On-Time Rate", value: viewModel.formatPercentage(metrics.onTimeDeliveryRate), icon: "clock.fill", color: .green)
                            KPIBox(title: "Distance (km)", value: String(format: "%.0f", metrics.distanceCovered), icon: "map.fill", color: .purple)
                            KPIBox(title: "Fuel (km/L)", value: String(format: "%.1f", metrics.fuelEfficiency), icon: "fuelpump.fill", color: .orange)
                        }
                        .padding(.horizontal)

                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle("My Performance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Sub-component: KPI Box
struct KPIBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppColor.surface)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}
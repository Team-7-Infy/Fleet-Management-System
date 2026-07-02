//
//  PerformanceView.swift
//  FMSD
//
//  Created by Dev Jain on 24/06/26.
//


import SwiftUI

struct PerformanceView: View {
    @StateObject private var viewModel = PerformanceViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all)
                
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
                                
                                ZStack {
                                    Circle()
                                        .stroke(lineWidth: 15)
                                        .opacity(0.2)
                                        .foregroundColor(viewModel.scoreColor(for: metrics.safetyScore))
                                    
                                    Circle()
                                        .trim(from: 0.0, to: CGFloat(metrics.safetyScore) / 100.0)
                                        .stroke(style: StrokeStyle(lineWidth: 15, lineCap: .round, lineJoin: .round))
                                        .foregroundColor(viewModel.scoreColor(for: metrics.safetyScore))
                                        .rotationEffect(Angle(degrees: 270.0))
                                        .animation(.easeInOut(duration: 1.5), value: metrics.safetyScore)
                                    
                                    VStack {
                                        Text("\(metrics.safetyScore)")
                                            .font(.system(size: 50, weight: .bold, design: .rounded))
                                        Text("Out of 100")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .frame(width: 180, height: 180)
                                .padding()
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.white)
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
                            
                            // List Section: Penalty Events
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Driving Events (This Month)")
                                    .font(.headline)
                                    .padding()
                                
                                Divider()
                                
                                EventRow(title: "Harsh Braking", count: metrics.harshBrakingEvents, limit: 5)
                                EventRow(title: "Speeding Alerts", count: metrics.speedingEvents, limit: 3)
                                EventRow(title: "Idle Time (Mins)", count: metrics.idleTimeMinutes, limit: 60)
                            }
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
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
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// Sub-component: Event Row
struct EventRow: View {
    let title: String
    let count: Int
    let limit: Int
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            Text("\(count)")
                .fontWeight(.bold)
                .foregroundColor(count > limit ? .red : .primary)
        }
        .padding()
        Divider()
    }
}
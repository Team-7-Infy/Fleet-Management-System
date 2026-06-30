//
//  FuelHistoryView.swift
//  FMSD
//
//  Created by Dev Jain on 24/06/26.
//


import SwiftUI

struct FuelHistoryView: View {
    @StateObject private var viewModel = FuelViewModel()
    @State private var showingRequestSheet = false
    
    var body: some View {
        List(viewModel.fuelHistory) { record in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(record.date, style: .date)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Spacer()
                    StatusBadge(status: record.status)
                }
                
                HStack {
                    VStack(alignment: .leading) {
                        Text(record.fuelType.rawValue)
                            .font(.headline)
                        if let volume = record.volumeFilled {
                            Text("\(volume, specifier: "%.1f") Liters")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    if let cost = record.cost {
                        Text("$\(cost, specifier: "%.2f")")
                            .font(.title3)
                            .fontWeight(.bold)
                    } else if let requested = record.amountRequested {
                        Text("Req: $\(requested, specifier: "%.2f")")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("Fuel Logs")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingRequestSheet = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
            }
        }
        .sheet(isPresented: $showingRequestSheet) {
            FuelRequestView()
        }
    }
}

// Reusable UI component for status badges
struct StatusBadge: View {
    let status: FuelRecord.RequestStatus
    
    var body: some View {
        Text(status.rawValue)
            .font(.caption)
            .fontWeight(.bold)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(backgroundColor.opacity(0.2))
            .foregroundColor(backgroundColor)
            .cornerRadius(12)
    }
    
    private var backgroundColor: Color {
        switch status {
        case .approved, .completed: return .green
        case .pending: return .orange
        case .rejected: return .red
        }
    }
}

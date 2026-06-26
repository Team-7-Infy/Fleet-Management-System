//
//  VehicleActionMenu.swift
//  FMS
//
//  Created by Veer on 26/06/26.
//


import SwiftUI


struct VehicleActionMenu: View {
    var vehicle: Vehicle
    @ObservedObject var viewModel: VehicleViewModel

    var body: some View {
        Menu {
            ForEach(VehicleStatus.allCases) { status in
                Button(status.title) {
                    Task { await viewModel.updateStatus(vehicle, status: status) }
                }
            }

            Divider()

            Button(role: .destructive) {
                Task { await viewModel.delete(vehicle) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("Vehicle actions")
    }
}

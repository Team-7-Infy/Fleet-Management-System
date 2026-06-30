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
    @State private var showDeleteConfirm = false

    var body: some View {
        Menu {
            ForEach(VehicleStatus.allCases) { status in
                Button(status.title) {
                    Task { await viewModel.updateStatus(vehicle, status: status) }
                }
            }

            Divider()

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("Vehicle actions")
        .alert("Delete Vehicle?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task { await viewModel.delete(vehicle) }
            }
        } message: {
            Text("Vehicle \(vehicle.licencePlate) (\(vehicle.make) \(vehicle.model)) will be permanently removed.")
        }
    }
}

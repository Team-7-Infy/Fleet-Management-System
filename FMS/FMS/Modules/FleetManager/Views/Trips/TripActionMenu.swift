//
//  TripActionMenu.swift
//  FMS
//
//  Created by Veer on 26/06/26.
//

import SwiftUI
struct TripActionMenu: View {
    var trip: Trip
    @ObservedObject var viewModel: TripManagementViewModel
    @State private var showDeleteConfirm = false

    var body: some View {
        Menu {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Delete / Cancel Trip", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("Trip actions")
        .alert("Delete Trip?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task { await viewModel.delete(trip) }
            }
        } message: {
            Text("Are you sure you want to delete/cancel this trip? This will unassign the driver from the vehicle.")
        }
    }
}

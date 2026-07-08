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
                Label("Cancel Trip", systemImage: "xmark.circle")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("Trip actions")
        .alert("Cancel Trip?", isPresented: $showDeleteConfirm) {
            Button("Keep Trip", role: .cancel) { }
            Button("Cancel Trip", role: .destructive) {
                Task { await viewModel.delete(trip) }
            }
        } message: {
            Text("Are you sure you want to cancel this trip? This will unassign the driver from the vehicle.")
        }
    }
}

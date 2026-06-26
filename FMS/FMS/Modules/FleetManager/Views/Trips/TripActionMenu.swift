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

    var body: some View {
        Menu {
            ForEach(TripStatus.allCases) { status in
                Button(status.title) {
                    Task { await viewModel.updateStatus(trip, status: status) }
                }
            }

            Divider()

            Button(role: .destructive) {
                Task { await viewModel.delete(trip) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("Trip actions")
    }
}

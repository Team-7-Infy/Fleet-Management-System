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
            Button {
            } label: {
                Label("Trips cannot be deleted", systemImage: "lock")
            }
            .disabled(true)
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("Trip actions")
    }
}

//
//  MaintenanceActionMenu.swift
//  FMS
//
//  Created by Veer on 26/06/26.
//



import SwiftUI

struct MaintenanceActionMenu: View {
    var task: MaintenanceTask
    var personnel: [MaintenancePersonnel]
    @ObservedObject var usersViewModel: UserManagementViewModel
    @ObservedObject var viewModel: MaintenanceViewModel

    var body: some View {
        Menu {
            Menu("Assign") {
                ForEach(personnel) { person in
                    Button(usersViewModel.user(for: person.userId)?.displayName ?? person.id.uuidString) {
                        Task { await viewModel.assignPersonnel(task: task, personnelId: person.id) }
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("Maintenance actions")
    }
}

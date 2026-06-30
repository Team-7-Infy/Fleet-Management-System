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
    @State private var showDeleteConfirm = false

    var body: some View {
        Menu {
            Menu("Assign") {
                ForEach(personnel) { person in
                    Button(usersViewModel.user(for: person.userId)?.displayName ?? person.id.uuidString) {
                        Task { await viewModel.assignPersonnel(task: task, personnelId: person.id) }
                    }
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
        .accessibilityLabel("Maintenance actions")
        .alert("Delete Work Order?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task { await viewModel.delete(task) }
            }
        } message: {
            Text("Work order \"\(task.description)\" will be permanently removed.")
        }
    }
}

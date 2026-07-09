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
            if task.status != .completed {
                Button {
                    Task { await viewModel.updateStatus(task, status: .completed) }
                } label: {
                    Label("Mark as Done", systemImage: "checkmark.circle")
                }
                Divider()
            }
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
                Label("Delete Task", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("Maintenance actions")
        .alert("Delete Task?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task { await viewModel.delete(task) }
            }
        }
    }
}

//
//  ManagerUserFormSheet.swift
//  FMS
//
//  Created by Veer on 26/06/26.
//
import SwiftUI

struct ManagerUserFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: UserManagementViewModel
    @State private var form = FleetManagerUserForm()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Create User")
                    .font(.title3.bold())
                    .foregroundStyle(FleetPalette.textPrimary)

                TextField("Name", text: $form.name)
                    .textContentType(.name)
                    .fleetField()
                TextField("Email / Login ID", text: $form.email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .fleetField()
                TextField("Aadhar", text: $form.aadhar)
                    .keyboardType(.numberPad)
                    .fleetField()
                TextField("Contact", text: $form.contact)
                    .keyboardType(.phonePad)
                    .fleetField()

                Picker("Role", selection: $form.role) {
                    Text(UserRole.driver.title).tag(UserRole.driver)
                    Text(UserRole.maintenancePersonnel.title).tag(UserRole.maintenancePersonnel)
                }
                .pickerStyle(.segmented)

                FeedbackView(success: viewModel.successMessage, error: viewModel.errorMessage)

                Button {
                    Task {
                        if await viewModel.createUser(form: form) {
                            dismiss()
                        }
                    }
                } label: {
                    Label("Create Credentials", systemImage: "person.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(FleetPalette.accent)
                .disabled(form.isValid == false)
            }
            .padding()
        }
        .fleetScreenBackground()
        .navigationTitle("Create User")
        .navigationBarTitleDisplayMode(.inline)
    }
}

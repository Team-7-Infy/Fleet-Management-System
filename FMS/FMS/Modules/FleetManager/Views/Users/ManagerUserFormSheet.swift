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
                TextField("First name", text: $form.firstName)
                    .textContentType(.givenName)
                    .fleetField()
                TextField("Last name", text: $form.lastName)
                    .textContentType(.familyName)
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
                TextField("Address", text: $form.address, axis: .vertical)
                    .lineLimit(2...4)
                    .fleetField()

                Picker("Role", selection: $form.role) {
                    Text(UserRole.driver.title).tag(UserRole.driver)
                    Text(UserRole.maintenancePersonnel.title).tag(UserRole.maintenancePersonnel)
                }
                .pickerStyle(.segmented)

                if form.role == .driver {
                    TextField("Licence number", text: $form.licenceNumber)
                        .textInputAutocapitalization(.characters)
                        .fleetField()

                    Picker("Vehicle Type", selection: $form.vehicleType) {
                        ForEach(["car", "van", "bus", "truck"], id: \.self) { type in
                            Text(type.capitalized).tag(type)
                        }
                    }
                }

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
                .tint(FleetPalette.primary)
                .disabled(form.isValid == false)
            }
            .padding()
        }
        .fleetScreenBackground()
        .navigationTitle("Create Login")
        .navigationBarTitleDisplayMode(.inline)
    }
}

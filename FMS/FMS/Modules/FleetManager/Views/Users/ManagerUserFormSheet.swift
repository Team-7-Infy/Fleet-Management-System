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
                FleetFieldValidationMessage(message: visibleValidationMessage(for: .name))

                TextField("Email / Login ID", text: $form.email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .fleetField()
                FleetFieldValidationMessage(message: visibleValidationMessage(for: .email))

                TextField("Aadhar", text: $form.aadhar)
                    .keyboardType(.numberPad)
                    .fleetField()
                FleetFieldValidationMessage(message: visibleValidationMessage(for: .aadhaar))

                TextField("Contact", text: $form.contact)
                    .keyboardType(.phonePad)
                    .fleetField()
                FleetFieldValidationMessage(message: visibleValidationMessage(for: .contact))

                Picker(selection: $form.role) {
                    Text(UserRole.driver.title).tag(UserRole.driver)
                    Text(UserRole.maintenancePersonnel.title).tag(UserRole.maintenancePersonnel)
                } label: {
                    HStack(spacing: 12) {
                        Label("Role", systemImage: "person.crop.circle.badge.checkmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(FleetPalette.textPrimary)

                        Spacer(minLength: 8)

                        Text(form.role.title)
                            .font(.body)
                            .foregroundStyle(FleetPalette.textSecondary)
                            .lineLimit(1)

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(FleetPalette.accent)
                    }
                    .contentShape(Rectangle())
                }
                .pickerStyle(.menu)
                .tint(FleetPalette.accent)
                .fleetField()

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
        .onChange(of: form.aadhar) { _, newValue in
            form.aadhar = String(UserProfileValidation.normalizedAadhaar(newValue).prefix(12))
        }
        .onChange(of: form.contact) { _, newValue in
            form.contact = String(UserProfileValidation.normalizedContact(newValue).prefix(10))
        }
    }

    private func visibleValidationMessage(for field: UserProfileValidationField) -> String? {
        switch field {
        case .name where form.normalizedName.isEmpty:
            return nil
        case .email where form.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty:
            return nil
        case .aadhaar where form.normalizedAadhaar.isEmpty:
            return nil
        case .contact where form.normalizedContact.isEmpty:
            return nil
        default:
            return form.validationMessage(for: field)
        }
    }
}

struct FleetFieldValidationMessage: View {
    var message: String?

    var body: some View {
        if let message {
            Label(message, systemImage: "exclamationmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(FleetPalette.danger)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(message)
        }
    }
}

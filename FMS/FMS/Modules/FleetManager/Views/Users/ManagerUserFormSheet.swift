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
            VStack(spacing: 24) {
                
                FleetFormSection(title: "Personal Information") {
                    FleetFormRow(icon: "person.fill", title: "Name") {
                        TextField("Full Name", text: $form.name)
                            .textContentType(.name)
                            .multilineTextAlignment(.trailing)
                    }
                    if let msg = visibleValidationMessage(for: .name) {
                        FleetFormValidationRow(message: msg)
                    }
                    Divider().padding(.leading, 44)
                    
                    FleetFormRow(icon: "envelope.fill", title: "Email") {
                        TextField("Email Address", text: $form.email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .multilineTextAlignment(.trailing)
                    }
                    if let msg = visibleValidationMessage(for: .email) {
                        FleetFormValidationRow(message: msg)
                    }
                    Divider().padding(.leading, 44)
                    
                    FleetFormRow(icon: "doc.text.fill", title: "Aadhar") {
                        TextField("12-digit number", text: $form.aadhar)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    if let msg = visibleValidationMessage(for: .aadhaar) {
                        FleetFormValidationRow(message: msg)
                    }
                    Divider().padding(.leading, 44)
                    
                    FleetFormRow(icon: "phone.fill", title: "Contact") {
                        TextField("10-digit number", text: $form.contact)
                            .keyboardType(.phonePad)
                            .multilineTextAlignment(.trailing)
                    }
                    if let msg = visibleValidationMessage(for: .contact) {
                        FleetFormValidationRow(message: msg)
                    }
                }
                
                FleetFormSection(title: "Role & Compensation") {
                    FleetFormRow(icon: "briefcase.fill", title: "User Type") {
                        Picker("User Type", selection: $form.role) {
                            Text(UserRole.driver.title).tag(UserRole.driver)
                            Text(UserRole.maintenancePersonnel.title).tag(UserRole.maintenancePersonnel)
                        }
                        .tint(FleetPalette.accent)
                        .labelsHidden()
                    }
                    
                    if form.role == .maintenancePersonnel {
                        Divider().padding(.leading, 44)
                        FleetFormRow(icon: "indianrupeesign.circle.fill", title: "Hourly Rate") {
                            TextField("Rate (₹/hr)", text: $form.hourlyRate)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
                .animation(.easeInOut, value: form.role)
                
                FeedbackView(success: viewModel.successMessage, error: viewModel.errorMessage)

                Button {
                    Task {
                        if await viewModel.createUser(form: form) {
                            dismiss()
                        }
                    }
                } label: {
                    Label("Create Credentials", systemImage: "person.badge.plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(FleetPalette.accent)
                .disabled(form.isValid == false)
                .padding(.top, 8)
            }
            .padding()
        }
        .fleetScreenBackground()
        .navigationTitle("Create User")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
                .tint(FleetPalette.textPrimary)
            }
        }
        .onChange(of: form.aadhar) { _, newValue in
            form.aadhar = String(UserProfileValidation.normalizedAadhaar(newValue).prefix(12))
        }
        .onChange(of: form.contact) { _, newValue in
            form.contact = String(UserProfileValidation.normalizedContact(newValue).prefix(10))
        }
    }

    private func visibleValidationMessage(for field: UserProfileValidationField) -> String? {
        switch field {
        case .name where form.normalizedName.isEmpty: return nil
        case .email where form.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty: return nil
        case .aadhaar where form.normalizedAadhaar.isEmpty: return nil
        case .contact where form.normalizedContact.isEmpty: return nil
        default: return form.validationMessage(for: field)
        }
    }
}

// MARK: - Reusable Form Components
struct FleetFormSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(FleetPalette.textSecondary)
                .padding(.leading, 8)
            
            VStack(spacing: 0) {
                content
            }
            .background(FleetPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(FleetPalette.tertiary.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

struct FleetFormRow<Content: View>: View {
    let icon: String
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(FleetPalette.accent)
                .frame(width: 24)
            
            Text(title)
                .font(.body)
                .foregroundStyle(FleetPalette.textPrimary)
            
            Spacer()
            
            content
                .foregroundStyle(FleetPalette.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

struct FleetFormValidationRow: View {
    let message: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
            Text(message)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(FleetPalette.danger)
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
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

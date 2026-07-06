import SwiftUI
import PhotosUI
internal import PostgREST

struct MPProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ProfileViewModel
    @State private var selectedItem: PhotosPickerItem?
    @State private var isEditing = false
    @State private var showErrorAlert = false
    private let onLogout: () -> Void
    
    init(dependencies: AppDependencyContainer, onLogout: @escaping () -> Void = {}) {
        _viewModel = StateObject(wrappedValue: ProfileViewModel(dependencies: dependencies))
        self.onLogout = onLogout
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: 0xF4F5F9).ignoresSafeArea()

            if viewModel.state.isLoading {
                LoadingView(title: "Loading profile")
            } else if let user = viewModel.userProfile {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {

                        heroCard(for: user)

                        VStack(alignment: .leading, spacing: 8) {
                            sectionHeader("PERSONAL INFORMATION")
                            personalInfoCard(for: user)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            sectionHeader("IDENTITY VERIFICATION")
                            identityVerificationCard(for: user)
                        }

                        if !isEditing {
                            VStack(alignment: .leading, spacing: 8) {
                                sectionHeader("ACCOUNT")
                                signOutButton
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                    .padding(.top, 8)
                }
            } else {
                MPEmptyStateView(title: "Profile Unavailable", message: "Could not load user data.", systemImage: "person.crop.circle.badge.exclamationmark")
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(isEditing ? "Save" : "Edit") {
                    handleEditButton()
                }
                .bold()
            }
        }
        .task {
            await viewModel.load()
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    await viewModel.updateProfileImage(with: data)
                }
            }
        }
        .alert(isPresented: $showErrorAlert) {
            Alert(
                title: Text("Validation Error"),
                message: Text(viewModel.validationError ?? "Please check your inputs and try again."),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func handleEditButton() {
        if isEditing {
            Task {
                do {
                    try await viewModel.updateProfileDetails()
                    isEditing = false
                } catch {
                    showErrorAlert = true
                }
            }
        } else {
            viewModel.populateEditFields()
            isEditing = true
        }
    }
    
    // MARK: - Sections
    
    private func heroCard(for user: UserProfile) -> some View {
        HStack(spacing: 16) {
            PhotosPicker(selection: $selectedItem, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    if let imageData = user.profileImageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 72, height: 72)
                            .clipShape(Circle())
                            .shadow(color: Color.blue.opacity(0.15), radius: 8, x: 0, y: 4)
                    } else {
                        // Initials Circle
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [Color.blue, Color.blue.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 72, height: 72)
                                .shadow(color: Color.blue.opacity(0.2), radius: 8, x: 0, y: 4)
                            
                            Text(initials(for: user.name))
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.white)
                        }
                    }
                    
                    if isEditing {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundStyle(Color.white, Color.blue)
                            .font(.system(size: 24))
                            .background(Circle().fill(Color.white))
                            .offset(x: 4, y: 4)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(!isEditing)
            
            VStack(alignment: .leading, spacing: 6) {
                if isEditing {
                    VStack(spacing: 4) {
                        TextField("First Name", text: $viewModel.editFirstName)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                        
                        TextField("Last Name", text: $viewModel.editLastName)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                    }
                } else {
                    HStack(spacing: 4) {
                        Text(user.name)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.black)
                            .lineLimit(1)
                        
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Color.blue)
                            .font(.system(size: 14))
                    }
                }
                
                Text("\(formatRole(user.role ?? "maintenance_personnel")) · Active")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.gray)
                
                // Status Pill
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("ON DUTY")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(Color.green)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.1))
                .clipShape(Capsule())
            }
            
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
    
    private func personalInfoCard(for user: UserProfile) -> some View {
        VStack(spacing: 0) {
            listRow(icon: "envelope.fill", iconColor: Color.blue, title: "Email", subtitle: user.email, isLast: false, isEditable: false, textBinding: .constant(""))
            if isEditing {
                listRow(icon: "phone.fill", iconColor: Color.green, title: "Phone Number", subtitle: viewModel.editContact, isLast: true, isEditable: true, textBinding: $viewModel.editContact, keyboardType: .numberPad)
            } else {
                listRow(icon: "phone.fill", iconColor: Color.green, title: "Phone Number", subtitle: user.contactNumber, isLast: true, isEditable: false, textBinding: .constant(""))
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
    
    private func identityVerificationCard(for user: UserProfile) -> some View {
        VStack(spacing: 0) {
            listRow(icon: "person.text.rectangle.fill", iconColor: Color.orange, title: "Aadhaar Number", subtitle: maskAadhaar(user.aadhaarNumber), isLast: false, isEditable: false, textBinding: .constant(""))
            if isEditing {
                listRow(icon: "mappin.and.ellipse", iconColor: Color.purple, title: "Current Address", subtitle: viewModel.editAddress, isLast: true, isEditable: true, textBinding: $viewModel.editAddress)
            } else {
                listRow(icon: "mappin.and.ellipse", iconColor: Color.purple, title: "Current Address", subtitle: user.address, isLast: true, isEditable: false, textBinding: .constant(""))
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
    
    private var signOutButton: some View {
        VStack(spacing: 0) {
            Button {
                dismiss()
                onLogout()
            } label: {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppColor.destructive.opacity(0.1))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "rectangle.portrait.and.arrow.right.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(AppColor.destructive)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sign Out")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.black)
                        Text("Log out of your account")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.gray)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Helpers
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(Color.gray)
            .padding(.leading, 12)
    }
    
    private func listRow(icon: String, iconColor: Color, title: String, subtitle: String, isLast: Bool, isEditable: Bool, textBinding: Binding<String>, keyboardType: UIKeyboardType = .default) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(iconColor.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(iconColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.black)
                    if isEditable {
                        TextField("Enter \(title.lowercased())", text: textBinding)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(keyboardType)
                            .autocorrectionDisabled()
                    } else {
                        Text(subtitle)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.gray)
                            .lineLimit(1)
                    }
                }
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            if !isLast {
                Divider().opacity(0.5).padding(.leading, 72)
            }
        }
    }
    
    private func maskAadhaar(_ number: String) -> String {
        let clean = number.replacingOccurrences(of: " ", with: "")
        guard clean.count >= 4 else { return number }
        let last4 = String(clean.suffix(4))
        return "XXXX XXXX \(last4)"
    }
    
    private func formatRole(_ role: String) -> String {
        return role.replacingOccurrences(of: "_", with: " ").capitalized
    }
    
    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        guard !parts.isEmpty else { return "" }
        if parts.count == 1 {
            return String(parts[0].prefix(2)).uppercased()
        }
        return (String(parts[0].prefix(1)) + String(parts[1].prefix(1))).uppercased()
    }
}

#Preview {
    MPProfileView(dependencies: .mock())
}

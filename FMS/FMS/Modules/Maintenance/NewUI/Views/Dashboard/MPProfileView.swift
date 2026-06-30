import SwiftUI
import PhotosUI

struct MPProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ProfileViewModel
    @State private var selectedItem: PhotosPickerItem?
    private let onLogout: () -> Void
    
    init(dependencies: AppDependencyContainer, onLogout: @escaping () -> Void = {}) {
        _viewModel = StateObject(wrappedValue: ProfileViewModel(dependencies: dependencies))
        self.onLogout = onLogout
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()
                
                if viewModel.state.isLoading {
                    LoadingView(title: "Loading profile")
                } else if let user = viewModel.userProfile {
                    ScrollView {
                        VStack(spacing: AppSpacing.large) {
                            heroSection(for: user)
                            
                            VStack(alignment: .leading, spacing: AppSpacing.large) {
                                sectionHeader("Personal Information")
                                personalInfoCard(for: user)
                                
                                sectionHeader("Identity Verification")
                                identityVerificationCard(for: user)
                                
                                signOutButton
                            }
                            .padding(.horizontal, AppSpacing.large)
                            .padding(.bottom, AppSpacing.xLarge)
                        }
                    }
                } else {
                    MPEmptyStateView(title: "Profile Unavailable", message: "Could not load user data.", systemImage: "person.crop.circle.badge.exclamationmark")
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
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
        }
    }
    
    // MARK: - Sections
    
    private func heroSection(for user: UserProfile) -> some View {
        VStack(spacing: AppSpacing.medium) {
            PhotosPicker(selection: $selectedItem, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    if let imageData = user.profileImageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .foregroundStyle(AppColor.brand)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
                    }
                    
                    // Edit Badge
                    Image(systemName: "camera.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppColor.brand)
                        .padding(4)
                        .background(Circle().fill(Color.white))
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
                        .offset(x: 0, y: 0)
                }
            }
            .buttonStyle(.plain)
            
            VStack(spacing: 4) {
                Text(user.name)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColor.textPrimary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, AppSpacing.xLarge)
        .padding(.bottom, AppSpacing.large)
    }
    
    private func personalInfoCard(for user: UserProfile) -> some View {
        VStack(spacing: 0) {
            infoRow(icon: "envelope.fill", title: "Email", value: user.email)
            Divider().padding(.leading, 48)
            infoRow(icon: "phone.fill", title: "Phone Number", value: user.contactNumber)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        )
    }
    
    private func identityVerificationCard(for user: UserProfile) -> some View {
        VStack(spacing: 0) {
            infoRow(icon: "person.text.rectangle.fill", title: "Aadhaar Number", value: user.aadhaarNumber)
            Divider().padding(.leading, 48)
            infoRow(icon: "mappin.and.ellipse", title: "Current Address", value: user.address)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        )
    }
    
    private var signOutButton: some View {
        Button {
            dismiss()
            onLogout()
        } label: {
            Text("Sign Out")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.red)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
                )
        }
        .buttonStyle(.plain)
        .padding(.top, AppSpacing.medium)
    }
    
    // MARK: - Helpers
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(AppColor.textPrimary)
            .padding(.leading, 4)
            .padding(.top, AppSpacing.medium)
    }
    
    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColor.brand.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(AppColor.brand)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14))
                    .foregroundStyle(AppColor.textSecondary)
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColor.textPrimary)
            }
            
            Spacer()
        }
        .padding(16)
    }
}

#Preview {
    MPProfileView(dependencies: .mock())
}

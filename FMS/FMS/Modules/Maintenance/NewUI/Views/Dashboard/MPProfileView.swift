import SwiftUI
import PhotosUI
internal import PostgREST

struct MPProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ProfileViewModel
    @State private var showingLogoutAlert = false
    @State private var showingEditSheet = false
    private let onLogout: () -> Void

    init(dependencies: AppDependencyContainer, onLogout: @escaping () -> Void = {}) {
        _viewModel = StateObject(wrappedValue: ProfileViewModel(dependencies: dependencies))
        self.onLogout = onLogout
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                if viewModel.state.isLoading {
                    ProgressView()
                        .padding(.top, 40)
                } else if let user = viewModel.userProfile {
                    VStack(spacing: 24) {
                        ProfileHeaderCard(viewModel: viewModel, user: user)

                        ProfilePerformanceSummary(
                            completionRate: viewModel.completionRate,
                            completedJobs: "\(viewModel.completedWorkOrdersCount)",
                            activeJobs: "\(viewModel.activeWorkOrdersCount)",
                            nextDueJobDate: viewModel.nextDueJobDate
                        )

                        ProfileInfoSection(title: "Contact Details", rows: [
                            ProfileInfoRow(title: "Mobile", value: user.contactNumber, icon: "phone.fill"),
                            ProfileInfoRow(title: "Email", value: user.email, icon: "envelope.fill")
                        ])
                        
                        ProfileInfoSection(title: "Personal Details", rows: [
                            ProfileInfoRow(title: "Aadhaar Number", value: maskAadhaar(user.aadhaarNumber), icon: "person.text.rectangle.fill"),
                            ProfileInfoRow(title: "Current Address", value: user.address, icon: "mappin.and.ellipse")
                        ])

                        Button(role: .destructive) {
                            HapticManager.shared.triggerNotification(type: .warning)
                            showingLogoutAlert = true
                        } label: {
                            Label("Sign Out", systemImage: "arrow.right.square")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                        Text("App Version 2.4.1 (Build 2046)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                } else {
                    MPEmptyStateView(title: "Profile Unavailable", message: "Could not load user data.", systemImage: "person.crop.circle.badge.exclamationmark")
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        HapticManager.shared.triggerImpact(style: .light)
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        HapticManager.shared.triggerImpact(style: .light)
                        viewModel.populateEditFields()
                        showingEditSheet = true
                    } label: {
                        Text("Edit")
                            .fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                EditMaintenanceProfileView(viewModel: viewModel)
            }
            .alert("Sign Out?", isPresented: $showingLogoutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    dismiss()
                    onLogout()
                }
            } message: {
                Text("This will end your active maintenance portal session.")
            }
            .task {
                await viewModel.load()
            }
        }
    }

    private func maskAadhaar(_ number: String) -> String {
        let clean = number.replacingOccurrences(of: " ", with: "")
        guard clean.count >= 4 else { return number }
        let last4 = String(clean.suffix(4))
        return "XXXX XXXX \(last4)"
    }
}

private struct ProfileHeaderCard: View {
    @ObservedObject var viewModel: ProfileViewModel
    let user: UserProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 16) {
                ZStack {
                    if let imageData = user.profileImageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 76, height: 76)
                            .clipShape(Circle())
                            .shadow(radius: 4, x: 0, y: 2)
                    } else {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, Color(red: 0.12, green: 0.32, blue: 0.82)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 76, height: 76)
                            .shadow(color: Color.blue.opacity(0.3), radius: 6, x: 0, y: 3)

                        Text(initials(for: user.name))
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                    }

                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: 76, height: 76)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(user.name)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.blue)
                            .font(.subheadline)
                    }

                    Text("Maintenance")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                        Text("Active")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.green)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.08), in: Capsule())
                }

                Spacer(minLength: 0)
            }

            Divider().opacity(0.6)

            HStack(spacing: 16) {
                ProfileHeaderMetric(title: "Personnel ID", value: String(user.id.uuidString.prefix(8)).uppercased())
                Divider().frame(height: 32)
                ProfileHeaderMetric(title: "Joined", value: formatDate(user.createdat))
            }
        }
        .padding(20)
        .profileCardStyle()
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap(\.first)
        return letters.map(String.init).joined().uppercased()
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "N/A" }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM, yyyy"
        return formatter.string(from: date)
    }
}

private struct ProfileHeaderMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ProfilePerformanceSummary: View {
    let completionRate: Int
    let completedJobs: String
    let activeJobs: String
    let nextDueJobDate: String

    var body: some View {
        ProfileSectionContainer(title: "Performance") {
            HStack(spacing: 12) {
                // Job completion rate gauge tile
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        ZStack {
                            Circle()
                                .stroke(Color.blue.opacity(0.12), lineWidth: 4)
                                .frame(width: 44, height: 44)
                            Circle()
                                .trim(from: 0.0, to: CGFloat(completionRate) / 100.0)
                                .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .frame(width: 44, height: 44)
                                .rotationEffect(.degrees(-90))
                            Text("\(completionRate)%")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.blue)
                        }
                        Spacer()
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Completion Rate")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("Completed vs assigned")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 112)
                .background(Color.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                ProfileScoreTile(title: "Completed", value: completedJobs, subtitle: "Resolved", icon: "wrench.fill")
                ProfileScoreTile(title: "Active Jobs", value: activeJobs, subtitle: "Remaining", icon: "clock.fill")
            }

            ProfilePlainRow(icon: "calendar.badge.clock", title: "Next Due Job", value: nextDueJobDate)
                .padding(.top, 4)
        }
    }
}

private struct ProfileScoreTile: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String

    var body: some View {
        let tint = ProfileIconBadge(icon: icon).tint
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 112)
        .background(tint.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct ProfileInfoSection: View {
    let title: String
    let rows: [ProfileInfoRow]

    var body: some View {
        ProfileSectionContainer(title: title) {
            ForEach(rows) { row in
                ProfilePlainRow(icon: row.icon, title: row.title, value: row.value, allowsMultiline: row.title == "Current Address")
                if row.id != rows.last?.id {
                    Divider().padding(.leading, 46).opacity(0.4)
                }
            }
        }
    }
}

private struct ProfileSectionContainer<Content: View>: View {
    let title: String
    private let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.leading, 4)

            VStack(spacing: 12) {
                content
            }
            .padding(16)
            .profileCardStyle()
        }
    }
}

private struct ProfilePlainRow: View {
    let icon: String
    let title: String
    let value: String
    var allowsMultiline = false

    var body: some View {
        HStack(alignment: allowsMultiline ? .top : .center, spacing: 12) {
            ProfileIconBadge(icon: icon)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(allowsMultiline ? 3 : 1)
                    .minimumScaleFactor(allowsMultiline ? 1 : 0.75)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

private struct ProfileIconBadge: View {
    let icon: String
    var customTint: Color? = nil

    var tint: Color {
        if let customTint { return customTint }
        switch icon {
        case "phone.fill", "wrench.fill": return .green
        case "envelope.fill", "clock.fill": return .orange
        case "person.text.rectangle.fill": return .indigo
        case "mappin.and.ellipse": return .blue
        case "calendar.badge.clock": return .purple
        default: return .blue
        }
    }

    var body: some View {
        Image(systemName: icon)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: 34, height: 34)
            .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private extension View {
    func profileCardStyle() -> some View {
        background(Color(UIColor.systemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.02), radius: 8, x: 0, y: 4)
            .shadow(color: Color.black.opacity(0.015), radius: 2, x: 0, y: 1)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(UIColor.separator).opacity(0.15), lineWidth: 0.5)
            )
    }
}

// MARK: - Edit Profile View
enum EditMaintenanceProfileField: Hashable {
    case firstName, lastName, phone, address
}

struct EditMaintenanceProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ProfileViewModel

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var phone: String = ""
    @State private var address: String = ""
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var profileImageData: Data? = nil
    @State private var showErrorAlert = false
    @State private var validationError: String? = nil

    @FocusState private var focusedField: EditMaintenanceProfileField?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Avatar selector card with EDIT overlay
                    VStack(spacing: 12) {
                        PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                            ZStack(alignment: .bottom) {
                                if let profileImageData, let uiImage = UIImage(data: profileImageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 96, height: 96)
                                        .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [.blue, Color(red: 0.12, green: 0.32, blue: 0.82)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 96, height: 96)
                                    Text(initials(for: firstName + " " + lastName))
                                        .font(.system(size: 32, weight: .bold))
                                        .foregroundStyle(.white)
                                }

                                // Translucent EDIT overlay at the lower third of the avatar circle
                                VStack(spacing: 1) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 10, weight: .bold))
                                    Text("EDIT")
                                        .font(.system(size: 8, weight: .black))
                                }
                                .foregroundStyle(.white)
                                .frame(width: 96, height: 32)
                                .background(Color.black.opacity(0.4))
                            }
                            .frame(width: 96, height: 96)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 3)
                            )
                        }
                        .onChange(of: selectedItem) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    await MainActor.run {
                                        profileImageData = data
                                    }
                                }
                            }
                        }

                        Text("Change Profile Photo")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.blue)
                    }
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(UIColor.secondarySystemGroupedBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color(UIColor.separator).opacity(0.1), lineWidth: 0.5)
                    )

                    // Separated Floating Input Cards
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Personal Contact Details")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .padding(.leading, 4)

                        VStack(spacing: 14) {
                            EditMaintenanceProfileRow(
                                icon: "person.fill",
                                title: "First Name",
                                placeholder: "First Name",
                                text: $firstName,
                                focusField: .firstName,
                                activeFocus: $focusedField
                            )

                            EditMaintenanceProfileRow(
                                icon: "person.fill",
                                title: "Last Name",
                                placeholder: "Last Name",
                                text: $lastName,
                                focusField: .lastName,
                                activeFocus: $focusedField
                            )

                            EditMaintenanceProfileRow(
                                icon: "phone.fill",
                                title: "Mobile Number",
                                placeholder: "+91 XXXXX XXXXX",
                                text: $phone,
                                keyboardType: .phonePad,
                                focusField: .phone,
                                activeFocus: $focusedField
                            )

                            EditMaintenanceProfileRow(
                                icon: "mappin.and.ellipse",
                                title: "Current Address",
                                placeholder: "Home Address",
                                text: $address,
                                isMultiline: true,
                                focusField: .address,
                                activeFocus: $focusedField
                            )
                        }
                    }

                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        HapticManager.shared.triggerImpact(style: .medium)
                        Task {
                            do {
                                try await viewModel.updateProfile(
                                    firstName: firstName,
                                    lastName: lastName,
                                    contact: phone,
                                    address: address,
                                    newProfileImageData: profileImageData
                                )
                                await MainActor.run {
                                    dismiss()
                                }
                            } catch {
                                await MainActor.run {
                                    validationError = error.localizedDescription
                                    showErrorAlert = true
                                }
                            }
                        }
                    }
                    .fontWeight(.bold)
                }
            }
            .alert(isPresented: $showErrorAlert) {
                Alert(
                    title: Text("Validation Error"),
                    message: Text(validationError ?? "Please check your inputs and try again."),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onAppear {
                if let user = viewModel.userProfile {
                    firstName = user.f_name ?? ""
                    lastName = user.l_name ?? ""
                    phone = user.contact != nil ? String(user.contact!) : ""
                    address = user.addressStr ?? ""
                    profileImageData = user.profileImageData
                }
            }
        }
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap(\.first)
        return letters.map(String.init).joined().uppercased()
    }
}

private struct EditMaintenanceProfileRow: View {
    let icon: String
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var autocapitalize = true
    var isMultiline = false

    let focusField: EditMaintenanceProfileField
    var activeFocus: FocusState<EditMaintenanceProfileField?>.Binding

    var isFocused: Bool {
        activeFocus.wrappedValue == focusField
    }

    var body: some View {
        HStack(alignment: isMultiline ? .top : .center, spacing: 14) {
            ProfileIconBadge(icon: icon)
                .padding(.top, isMultiline ? 4 : 0)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isFocused ? .blue : .secondary)
                    .textCase(.uppercase)
                    .tracking(1.0)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        if isMultiline {
                            TextField(placeholder, text: $text, axis: .vertical)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                                .lineLimit(3)
                                .focused(activeFocus, equals: focusField)
                        } else {
                            TextField(placeholder, text: $text)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                                .keyboardType(keyboardType)
                                .textInputAutocapitalization(autocapitalize ? .words : .never)
                                .focused(activeFocus, equals: focusField)
                        }

                        Spacer(minLength: 0)

                        if isFocused {
                            if !text.isEmpty {
                                Button {
                                    text = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(Color(UIColor.tertiaryLabel))
                                        .font(.subheadline)
                                }
                                .transition(.opacity)
                            }
                        } else {
                            Image(systemName: "pencil")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .opacity(0.6)
                        }
                    }

                    // Inset baseline layout border beneath inputs
                    Rectangle()
                        .fill(isFocused ? Color.blue : Color(UIColor.separator).opacity(0.3))
                        .frame(height: isFocused ? 1.5 : 0.75)
                        .padding(.top, 2)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isFocused ? Color.blue : Color(UIColor.separator).opacity(0.15), lineWidth: isFocused ? 1.5 : 0.5)
        )
        .shadow(color: isFocused ? Color.blue.opacity(0.04) : Color.clear, radius: 8, x: 0, y: 4)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

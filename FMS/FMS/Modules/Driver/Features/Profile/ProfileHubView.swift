import SwiftUI
import PhotosUI

struct ProfileHubView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: DriverProfileViewModel
    @State private var showingLogoutAlert = false
    @State private var showingEditSheet = false
    var onLogout: (() -> Void)? = nil

    init(services: AppServices, driver: Driver?, user: User, onLogout: (() -> Void)? = nil) {
        self.onLogout = onLogout
        _viewModel = StateObject(wrappedValue: DriverProfileViewModel(services: services, driver: driver, user: user))
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    ProfileHeaderCard(viewModel: viewModel)

                    // 1. Performance Summary Card
                    ProfilePerformanceSummary(
                        safetyScore: viewModel.safetyScore,
                        totalTrips: "\(viewModel.completedTrips)",
                        onTimeRate: viewModel.onTimeRate,
                        lastTripDate: viewModel.lastTripDate
                    )

                    // 2. Contact & Personal Info Cards
                    ProfileInfoSection(title: "Contact Details", rows: viewModel.contactDetails)
                    ProfileInfoSection(title: "Personal Details", rows: viewModel.personalDetails)

                    // 3. Contact History Archive (if not empty)
                    if !viewModel.contactHistory.isEmpty {
                        ProfileHistorySection(history: viewModel.contactHistory)
                    }

                    // Sign Out Button
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
                        showingEditSheet = true
                    } label: {
                        Text("Edit")
                            .fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                EditProfileView(viewModel: viewModel)
            }
            .alert("Sign Out?", isPresented: $showingLogoutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    onLogout?()
                }
            } message: {
                Text("This will end your active driver portal session.")
            }
            .task {
                await viewModel.loadStats()
            }
        }
    }
}

private struct ProfileHeaderCard: View {
    @ObservedObject var viewModel: DriverProfileViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 16) {
                ZStack {
                    if let imageData = viewModel.profileImageData, let uiImage = UIImage(data: imageData) {
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

                        Text(viewModel.initials)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                    }

                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: 76, height: 76)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(viewModel.driverName)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.blue)
                            .font(.subheadline)
                    }

                    Text("Driver")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                        Text(viewModel.status)
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
                ProfileHeaderMetric(title: "Driver ID", value: viewModel.licenseNumber)
                Divider().frame(height: 32)
                ProfileHeaderMetric(title: "Joined", value: viewModel.dateOfJoining)
            }
        }
        .padding(20)
        .profileCardStyle()
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
    let safetyScore: Int
    let totalTrips: String
    let onTimeRate: String
    let lastTripDate: String

    var body: some View {
        ProfileSectionContainer(title: "Performance") {
            HStack(spacing: 12) {
                // Safety score gauge tile
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        ZStack {
                            Circle()
                                .stroke(Color.blue.opacity(0.12), lineWidth: 4)
                                .frame(width: 44, height: 44)
                            Circle()
                                .trim(from: 0.0, to: CGFloat(safetyScore) / 100.0)
                                .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .frame(width: 44, height: 44)
                                .rotationEffect(.degrees(-90))
                            Text("\(safetyScore)")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.blue)
                        }
                        Spacer()
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Safety Score")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("Based on telematics")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 112)
                .background(Color.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                ProfileScoreTile(title: "Trips", value: totalTrips, subtitle: "Completed", icon: "road.lanes")
                ProfileScoreTile(title: "On Time", value: onTimeRate, subtitle: "Rate", icon: "timer")
            }

            ProfilePlainRow(icon: "calendar.badge.clock", title: "Last Trip Date", value: lastTripDate)
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
                ProfilePlainRow(icon: row.icon, title: row.title, value: row.value, allowsMultiline: row.title == "Address")
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

private struct ProfileNavigationRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            ProfileIconBadge(icon: icon, customTint: tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 12)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

private struct ProfileIconBadge: View {
    let icon: String
    var customTint: Color? = nil

    var tint: Color {
        if let customTint { return customTint }
        switch icon {
        case "phone.fill", "road.lanes": return .green
        case "envelope.fill", "timer": return .orange
        case "sos.circle.fill", "drop.fill", "cross.case.fill": return .red
        case "mappin.and.ellipse", "shield.fill", "checkmark.seal.fill": return .blue
        case "person.text.rectangle.fill", "truck.box.fill": return .indigo
        case "calendar", "shield.lefthalf.filled", "calendar.badge.clock": return .purple
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

// MARK: - Support Sheet View
struct SupportView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Emergency Helpline")) {
                    Button(action: {
                        if let url = URL(string: "tel://100") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Label("Call Main Dispatch (Urgent)", systemImage: "phone.bubble.left.fill")
                            .foregroundColor(.red)
                            .fontWeight(.bold)
                    }
                }

                Section(header: Text("Office Support")) {
                    Label("E-mail: support@fleetops.com", systemImage: "envelope.fill")
                    Label("Office Hours: 09:00 - 18:00", systemImage: "clock.fill")
                }
            }
            .navigationTitle("Emergency Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Edit Profile View
enum EditProfileField: Hashable {
    case name, phone, email, address
}

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: DriverProfileViewModel

    @State private var name: String = ""
    @State private var phone: String = ""
    @State private var email: String = ""
    @State private var address: String = ""
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var profileImageData: Data? = nil

    @FocusState private var focusedField: EditProfileField?

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
                                    Text(viewModel.initials)
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
                        .onChange(of: selectedItem) { newItem in
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
                            EditProfileRow(
                                icon: "person.fill",
                                title: "Full Name",
                                placeholder: "Alex Johnson",
                                text: $name,
                                focusField: .name,
                                activeFocus: $focusedField
                            )

                            EditProfileRow(
                                icon: "phone.fill",
                                title: "Mobile Number",
                                placeholder: "+91 XXXXX XXXXX",
                                text: $phone,
                                keyboardType: .phonePad,
                                focusField: .phone,
                                activeFocus: $focusedField
                            )

                            EditProfileRow(
                                icon: "envelope.fill",
                                title: "Email Address",
                                placeholder: "alex@fleetops.com",
                                text: $email,
                                keyboardType: .emailAddress,
                                autocapitalize: false,
                                focusField: .email,
                                activeFocus: $focusedField
                            )

                            EditProfileRow(
                                icon: "mappin.and.ellipse",
                                title: "Home Address",
                                placeholder: "Flat 402, Highrise Apartments",
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
                    .foregroundStyle(.secondary) // Secondary visual weight
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        HapticManager.shared.triggerImpact(style: .medium)
                        viewModel.updateProfile(newName: name, newPhone: phone, newEmail: email, newAddress: address, newProfileImageData: profileImageData)
                        dismiss()
                    }
                    .fontWeight(.bold) // Primary visual weight
                }
            }
            .onAppear {
                name = viewModel.driverName
                phone = viewModel.phone
                email = viewModel.email
                address = viewModel.address
                profileImageData = viewModel.profileImageData
            }
        }
    }
}

private struct EditProfileRow: View {
    let icon: String
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var autocapitalize = true
    var isMultiline = false

    let focusField: EditProfileField
    var activeFocus: FocusState<EditProfileField?>.Binding

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

private struct ProfileHistorySection: View {
    let history: [ContactHistoryItem]

    var body: some View {
        ProfileSectionContainer(title: "Archived Contacts") {
            ForEach(history) { item in
                HStack(alignment: .top, spacing: 12) {
                    ProfileIconBadge(icon: "clock.arrow.circlepath", customTint: .purple)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.field)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(item.date, style: .date)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Text(item.oldValue)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(.vertical, 4)

                if item.id != history.last?.id {
                    Divider().padding(.leading, 46).opacity(0.4)
                }
            }
        }
    }
}

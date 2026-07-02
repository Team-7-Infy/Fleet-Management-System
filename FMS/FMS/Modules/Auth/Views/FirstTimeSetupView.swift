import SwiftUI

struct FirstTimeSetupView: View {
    @Environment(\.colorScheme) private var colorScheme

    private let authService: AuthServiceProtocol
    private let user: User
    private let onComplete: (User) -> Void
    private let onLogout: () -> Void

    @State private var profileName: String
    @State private var profileEmail: String
    @State private var profileContact: String
    @State private var profileAddress: String
    @State private var profileAadhar: String
    @State private var profileAvatarUrl: String
    @State private var licenceNumber = ""
    @State private var vehicleType = "van"
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isNewPasswordVisible = false
    @State private var isConfirmPasswordVisible = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    init(authService: AuthServiceProtocol, user: User, onComplete: @escaping (User) -> Void, onLogout: @escaping () -> Void = {}) {
        self.authService = authService
        self.user = user
        self.onComplete = onComplete
        self.onLogout = onLogout
        _profileName = State(initialValue: user.displayName)
        _profileEmail = State(initialValue: user.email)
        _profileContact = State(initialValue: user.contact == 0 ? "" : "\(user.contact)")
        _profileAddress = State(initialValue: user.address)
        _profileAadhar = State(initialValue: user.aadhar)
        _profileAvatarUrl = State(initialValue: user.avatarUrl ?? "")
    }

    private enum Field { case newPassword, confirmPassword }

    private enum PasswordStrength: String {
        case empty, veryWeak, weak, fair, strong, veryStrong

        var color: Color {
            switch self {
            case .empty:      return .clear
            case .veryWeak:   return FleetPalette.danger
            case .weak:       return FleetPalette.danger
            case .fair:       return FleetPalette.warning
            case .strong:     return FleetPalette.success
            case .veryStrong: return FleetPalette.success
            }
        }

        var progress: Double {
            switch self {
            case .empty:      return 0
            case .veryWeak:   return 0.15
            case .weak:       return 0.35
            case .fair:       return 0.55
            case .strong:     return 0.75
            case .veryStrong: return 1.0
            }
        }
    }

    private var strength: PasswordStrength {
        guard !newPassword.isEmpty else { return .empty }
        var score = 0
        if newPassword.count >= 8 { score += 1 }
        if newPassword.rangeOfCharacter(from: .uppercaseLetters) != nil { score += 1 }
        if newPassword.rangeOfCharacter(from: .lowercaseLetters) != nil { score += 1 }
        if newPassword.rangeOfCharacter(from: .decimalDigits) != nil { score += 1 }
        let special = CharacterSet.alphanumerics.union(.whitespaces).inverted
        if newPassword.rangeOfCharacter(from: special) != nil { score += 1 }
        switch score {
        case 0, 1: return .veryWeak
        case 2:    return .weak
        case 3:    return .fair
        case 4:    return .strong
        default:   return .veryStrong
        }
    }

    private var passwordsMatch: Bool {
        !newPassword.isEmpty && newPassword == confirmPassword
    }

    private var profileContactValue: Int64? {
        guard UserProfileValidation.isValidContact(profileContact) else { return nil }
        return Int64(UserProfileValidation.normalizedContact(profileContact))
    }

    private var profileValidationIssues: [UserProfileValidationIssue] {
        var issues: [UserProfileValidationIssue] = []

        if UserProfileValidation.isValidName(profileName) == false {
            issues.append(UserProfileValidationIssue(
                field: .name,
                message: "Enter a valid name using letters, spaces, apostrophes, or hyphens."
            ))
        }

        if UserProfileValidation.isValidEmail(profileEmail) == false {
            issues.append(UserProfileValidationIssue(
                field: .email,
                message: "Enter a valid email address."
            ))
        }

        if UserProfileValidation.isValidContact(profileContact) == false {
            issues.append(UserProfileValidationIssue(
                field: .contact,
                message: "Contact must be a 10-digit mobile number starting with 6, 7, 8, or 9."
            ))
        }

        if user.role == .driver || user.role == .maintenancePersonnel {
            if UserProfileValidation.isValidAddress(profileAddress) == false {
                issues.append(UserProfileValidationIssue(
                    field: .address,
                    message: "Address must be 5-160 characters and use only common address characters."
                ))
            }

            if UserProfileValidation.isValidAadhaar(profileAadhar) == false {
                issues.append(UserProfileValidationIssue(
                    field: .aadhaar,
                    message: "Aadhaar must be exactly 12 digits."
                ))
            }
        }

        if UserProfileValidation.isValidOptionalURL(profileAvatarUrl) == false {
            issues.append(UserProfileValidationIssue(
                field: .avatarURL,
                message: "Photo URL must start with http:// or https://."
            ))
        }

        if user.role == .driver,
           UserProfileValidation.isValidLicenceNumber(licenceNumber, allowsPending: false) == false {
            issues.append(UserProfileValidationIssue(
                field: .licenceNumber,
                message: "Licence must look like DL-042026-7101 or MH12 2026 1234567."
            ))
        }

        return issues
    }

    private var isProfileValid: Bool {
        profileValidationIssues.isEmpty
    }

    private var isValid: Bool {
        isProfileValid && (strength == .strong || strength == .veryStrong) && passwordsMatch
    }

    var body: some View {
        ZStack {
            pageBackground.ignoresSafeArea()
            passwordSetup
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Sign Out") { onLogout() }
                    .foregroundStyle(FleetPalette.danger)
            }
        }
        .onChange(of: profileContact) { _, newValue in
            profileContact = String(UserProfileValidation.normalizedContact(newValue).prefix(10))
        }
        .onChange(of: profileAadhar) { _, newValue in
            profileAadhar = String(UserProfileValidation.normalizedAadhaar(newValue).prefix(12))
        }
        .onChange(of: licenceNumber) { _, newValue in
            licenceNumber = UserProfileValidation.normalizedLicenceNumber(newValue)
        }
        .onTapGesture { focusedField = nil }
    }

    // MARK: - Password Setup

    private var passwordSetup: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Welcome, \(user.fName)!")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)

                        Text("Confirm your profile details and set a secure password to activate your account.")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, 24)

                    profileCard
                        .padding(.top, 18)
                        .padding(.horizontal, 24)

                    passwordCard
                        .padding(.top, 18)
                        .padding(.horizontal, 24)

                    if let errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                            Text(errorMessage)
                        }
                        .font(.caption)
                        .foregroundStyle(FleetPalette.danger)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                    }
                }
                .padding(.bottom, 18)
            }

            Button(action: setPassword) {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView().tint(.white)
                    }
                    Text("Save Profile & Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
            }
            .buttonStyle(FleetGlassButtonStyle())
            .buttonBorderShape(.capsule)
            .padding(.horizontal, 24)
            .disabled(!isValid || isLoading)

            Button {
                onLogout()
            } label: {
                Text("Cancel Activation")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
            .buttonStyle(.plain)
            .background(.regularMaterial, in: Capsule())
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private var passwordCard: some View {
        VStack(spacing: 20) {
            Text("Security")
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 10) {
                Text("New password")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                glassField {
                    Image(systemName: "lock")

                    Group {
                        if isNewPasswordVisible {
                            TextField("", text: $newPassword, prompt: Text("Required").foregroundStyle(placeholderColor))
                        } else {
                            SecureField("", text: $newPassword, prompt: Text("Required").foregroundStyle(placeholderColor))
                        }
                    }
                    .foregroundStyle(.primary)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .newPassword)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .confirmPassword }

                    Button {
                        isNewPasswordVisible.toggle()
                    } label: {
                        Image(systemName: isNewPasswordVisible ? "eye.slash" : "eye")
                            .contentTransition(.symbolEffect(.replace))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                }

                if !newPassword.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        GeometryReader { bar in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.primary.opacity(0.08))
                                    .frame(height: 4)
                                Capsule()
                                    .fill(strength.color)
                                    .frame(width: bar.size.width * strength.progress, height: 4)
                                    .animation(.spring(duration: 0.4), value: strength.progress)
                            }
                        }
                        .frame(height: 4)

                        Text(strength == .empty ? "" : strength.rawValue.uppercased())
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(strength.color)
                            .animation(.default, value: strength.rawValue)
                    }
                }
            }

            Divider().padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 10) {
                Text("Confirm password")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                glassField {
                    Image(systemName: "arrow.trianglehead.clockwise")

                    Group {
                        if isConfirmPasswordVisible {
                            TextField("", text: $confirmPassword, prompt: Text("Match password").foregroundStyle(placeholderColor))
                        } else {
                            SecureField("", text: $confirmPassword, prompt: Text("Match password").foregroundStyle(placeholderColor))
                        }
                    }
                    .foregroundStyle(.primary)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .confirmPassword)
                    .submitLabel(.done)
                    .onSubmit { focusedField = nil }

                    Button {
                        isConfirmPasswordVisible.toggle()
                    } label: {
                        Image(systemName: isConfirmPasswordVisible ? "eye.slash" : "eye")
                            .contentTransition(.symbolEffect(.replace))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(cardBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(.white.opacity(colorScheme == .dark ? 0.08 : 0.7), lineWidth: 0.8)
                }
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.34 : 0.1), radius: 24, x: 0, y: 14)
        }
    }

    private var profileCard: some View {
        VStack(spacing: 16) {
            Text("Personal Information")
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            profileField("Name", systemImage: "person", text: $profileName, keyboardType: .default, validationMessage: visibleProfileValidationMessage(for: .name))
            profileField("Email", systemImage: "envelope", text: $profileEmail, keyboardType: .emailAddress, validationMessage: visibleProfileValidationMessage(for: .email))
            profileField("Contact no.", systemImage: "phone", text: $profileContact, keyboardType: .phonePad, validationMessage: visibleProfileValidationMessage(for: .contact))

            if user.role == .driver || user.role == .maintenancePersonnel {
                profileField("Address", systemImage: "mappin.and.ellipse", text: $profileAddress, keyboardType: .default, validationMessage: visibleProfileValidationMessage(for: .address))
                profileField("Aadhaar no.", systemImage: "number", text: $profileAadhar, keyboardType: .numberPad, validationMessage: visibleProfileValidationMessage(for: .aadhaar))
                profileField("Photo / DP URL", systemImage: "photo", text: $profileAvatarUrl, keyboardType: .URL, validationMessage: visibleProfileValidationMessage(for: .avatarURL))
            }

            if user.role == .driver {
                profileField("Driving licence", systemImage: "doc.text", text: $licenceNumber, keyboardType: .default, validationMessage: visibleProfileValidationMessage(for: .licenceNumber))

                Picker("Vehicle Type", selection: $vehicleType) {
                    ForEach(["car", "van", "bus", "truck"], id: \.self) { type in
                        Text(type.capitalized).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(cardBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(.white.opacity(colorScheme == .dark ? 0.08 : 0.7), lineWidth: 0.8)
                }
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.34 : 0.1), radius: 24, x: 0, y: 14)
        }
    }

    private func setPassword() {
        guard isValid else { return }
        isLoading = true
        errorMessage = nil
        Task { @MainActor in
            do {
                try await authService.forceUpdatePassword(userId: user.id, password: newPassword)
                guard let contact = profileContactValue else {
                    throw AuthError.functionError("Enter a valid contact number.")
                }
                let activatedUser = try await authService.completeFirstTimeProfile(
                    user: user,
                    name: UserProfileValidation.normalizedName(profileName),
                    email: UserProfileValidation.normalizedEmail(profileEmail),
                    contact: contact,
                    address: profileAddress.trimmingCharacters(in: .whitespacesAndNewlines),
                    aadhar: UserProfileValidation.normalizedAadhaar(profileAadhar),
                    avatarUrl: UserProfileValidation.normalizedURL(profileAvatarUrl),
                    licenceNumber: UserProfileValidation.normalizedLicenceNumber(licenceNumber),
                    vehicleType: vehicleType
                )
                isLoading = false
                onComplete(activatedUser)
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Shared UI

    private func profileField(
        _ label: String,
        systemImage: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType,
        validationMessage: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            glassField {
                Image(systemName: systemImage)

                TextField("", text: text, prompt: Text(label).foregroundStyle(placeholderColor))
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(keyboardType == .emailAddress || keyboardType == .URL ? .never : .words)
                    .foregroundStyle(.primary)
                    .frame(minWidth: 0, maxWidth: .infinity)
            }

            if let validationMessage {
                Label(validationMessage, systemImage: "exclamationmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FleetPalette.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func visibleProfileValidationMessage(for field: UserProfileValidationField) -> String? {
        switch field {
        case .name where UserProfileValidation.normalizedName(profileName).isEmpty:
            return nil
        case .email where profileEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty:
            return nil
        case .contact where UserProfileValidation.normalizedContact(profileContact).isEmpty:
            return nil
        case .address where profileAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty:
            return nil
        case .aadhaar where UserProfileValidation.normalizedAadhaar(profileAadhar).isEmpty:
            return nil
        case .avatarURL where profileAvatarUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty:
            return nil
        case .licenceNumber where UserProfileValidation.normalizedLicenceNumber(licenceNumber).isEmpty:
            return nil
        default:
            return profileValidationIssues.first { $0.field == field }?.message
        }
    }

    private func glassField<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            content()
        }
        .font(.body)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .frame(height: 56)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
    }

    private var placeholderColor: Color {
        colorScheme == .dark ? Color(white: 0.72) : Color(white: 0.38)
    }

    private var pageBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.035, green: 0.04, blue: 0.05)
            : FleetPalette.background
    }

    private var cardBackground: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.075)
            : Color.white.opacity(0.82)
    }
}

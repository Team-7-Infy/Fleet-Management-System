import Foundation
import SwiftUI
import Combine
import Supabase

@MainActor
final class DriverProfileViewModel: ObservableObject {
    let services: AppServices
    let driver: Driver?
    private var user: User

    var driverId: UUID? { driver?.id }

    @Published var driverName: String
    @Published var phone: String
    @Published var email: String
    @Published var address: String
    @Published var contactHistory: [ContactHistoryItem] = []
    @Published var profileImageData: Data? = nil
    @Published var profileImageURL: URL?
    @Published var isSavingProfile = false
    @Published var errorMessage: String?

    @Published var totalTrips: String = "0"
    @Published var completedTrips: Int = 0
    @Published var onTimeRate: String = "0%"
    @Published var safetyScore: Int = 85
    @Published var lastTripDate: String = "N/A"
    @Published var status: PersonnelStatus

    let dateOfJoining: String
    let licenseNumber: String
    let aadharNumber: String
    let assignedVehicle: String

    var statusText: String {
        status.title
    }

    var statusColor: Color {
        FleetPalette.personnelStatus(status)
    }

    var canToggleAvailability: Bool {
        status == .available || status == .unavailable
    }

    init(services: AppServices, driver: Driver?, user: User) {
        self.services = services
        self.driver = driver
        self.user = user

        driverName = "\(user.fName) \(user.lName)"
        phone = String(user.contact)
        email = user.email
        address = user.address
        profileImageURL = Self.savedAvatarURL(for: user)

        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM, yyyy"
        dateOfJoining = formatter.string(from: user.createdAt)
        licenseNumber = driver?.licenceNum ?? "N/A"
        aadharNumber = user.aadhar
        assignedVehicle = driver?.vehicleType ?? "None"
        status = driver?.status ?? .active
    }

    func loadStats() async {
        guard let driverId = driver?.id else { return }
        do {
            let trips = try await services.tripService.fetchTrips(forDriverId: driverId)
            let completed = trips.filter { $0.status == .completed }
            let scoreRecord = try? await services.userManagementService.fetchDriverScore(driverId: driverId)

            await MainActor.run {
                self.completedTrips = completed.count
                self.totalTrips = "\(trips.count)"
                self.onTimeRate = trips.isEmpty ? "0%" : "\(Int(Double(completed.count) / Double(trips.count) * 100))%"
                self.safetyScore = Int(scoreRecord?.overallScore ?? 75)

                if let last = trips.max(by: { ($0.startTime) < ($1.startTime) }) {
                    let f = DateFormatter()
                    f.dateFormat = "dd MMM, yyyy"
                    self.lastTripDate = f.string(from: last.startTime)
                }
            }
        } catch {
            print("Failed to load profile stats: \(error)")
        }
    }

    func setStatus(_ newStatus: PersonnelStatus) async {
        guard let driver = driver else { return }
        do {
            try await services.userManagementService.updateDriverStatus(driverId: driver.id, status: newStatus.rawValue)
            await MainActor.run {
                self.status = newStatus
            }
        } catch {
            print("Failed to update status: \(error)")
        }
    }

    var initials: String {
        let parts = driverName.split(separator: " ")
        let letters = parts.prefix(2).compactMap(\.first)
        return letters.map(String.init).joined().uppercased()
    }

    var personalDetails: [ProfileInfoRow] {
        [
            ProfileInfoRow(title: "Address", value: address, icon: "mappin.and.ellipse")
        ]
    }

    var contactDetails: [ProfileInfoRow] {
        [
            ProfileInfoRow(title: "Mobile", value: phone, icon: "phone.fill"),
            ProfileInfoRow(title: "Email", value: email, icon: "envelope.fill")
        ]
    }

    func updateProfile(newName: String, newPhone: String, newEmail: String, newAddress: String, newProfileImageData: Data?) async -> Bool {
        let normalizedName = UserProfileValidation.normalizedName(newName)
        let normalizedEmail = UserProfileValidation.normalizedEmail(newEmail)
        let normalizedPhone = UserProfileValidation.normalizedContact(newPhone)
        let normalizedAddress = newAddress.trimmingCharacters(in: .whitespacesAndNewlines)

        guard UserProfileValidation.isValidName(normalizedName) else {
            errorMessage = "Enter a valid full name."
            return false
        }
        guard UserProfileValidation.isValidEmail(normalizedEmail) else {
            errorMessage = "Enter a valid email address."
            return false
        }
        guard UserProfileValidation.isValidContact(normalizedPhone), let contact = Int64(normalizedPhone) else {
            errorMessage = "Enter a valid 10-digit mobile number."
            return false
        }
        guard UserProfileValidation.isValidAddress(normalizedAddress) else {
            errorMessage = "Enter a valid address."
            return false
        }

        isSavingProfile = true
        defer { isSavingProfile = false }

        do {
            // Check uniqueness of phone and email
            let allUsers = try await services.userManagementService.fetchUsers()
            if allUsers.contains(where: { $0.id != user.id && String($0.contact) == normalizedPhone }) {
                errorMessage = "This phone number is already associated with another account."
                return false
            }
            if allUsers.contains(where: { $0.id != user.id && $0.email.lowercased() == normalizedEmail.lowercased() }) {
                errorMessage = "This email is already associated with another account."
                return false
            }

            var updatedUser = user
            let nameParts = splitName(normalizedName)
            updatedUser.fName = nameParts.first
            updatedUser.lName = nameParts.last
            updatedUser.email = normalizedEmail
            updatedUser.contact = contact
            updatedUser.address = normalizedAddress

            if let newProfileImageData,
               newProfileImageData != profileImageData {
                updatedUser.avatarUrl = try await uploadProfileImage(newProfileImageData)
            }

            let savedUser = try await services.userManagementService.updateUser(updatedUser)
            apply(savedUser: savedUser, imageData: newProfileImageData)
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func apply(savedUser: User, imageData: Data?) {
        let newName = savedUser.displayName
        let newPhone = String(savedUser.contact)
        let newEmail = savedUser.email
        let newAddress = savedUser.address

        if newName != driverName {
            contactHistory.insert(ContactHistoryItem(field: "Name", oldValue: driverName), at: 0)
            driverName = newName
        }
        if newPhone != phone {
            contactHistory.insert(ContactHistoryItem(field: "Mobile", oldValue: phone), at: 0)
            phone = newPhone
        }
        if newEmail != email {
            contactHistory.insert(ContactHistoryItem(field: "Email", oldValue: email), at: 0)
            email = newEmail
        }
        if newAddress != address {
            contactHistory.insert(ContactHistoryItem(field: "Address", oldValue: address), at: 0)
            address = newAddress
        }
        if imageData != profileImageData {
            profileImageData = imageData
        }

        user = savedUser
        profileImageURL = Self.savedAvatarURL(for: savedUser)
    }

    private func uploadProfileImage(_ imageData: Data) async throws -> String {
        let uploadData = compressedImageData(from: imageData)
        let bucketId = "maintenance"
        let path = "avatar-\(user.id.uuidString)-\(Int(Date().timeIntervalSince1970)).jpg"

        let publicURL = try services.supabase.client.storage
            .from(bucketId)
            .getPublicURL(path: path)
            .absoluteString

        let baseURL = EnvironmentConfig.supabaseURL
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        components.path = "/storage/v1/object/\(bucketId)/\(path)"
        guard let uploadURL = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.setValue("3600", forHTTPHeaderField: "cache-control")
        request.setValue("true", forHTTPHeaderField: "x-upsert")
        request.setValue(EnvironmentConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        if let token = try? await services.supabase.client.auth.session.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = uploadData

        let (_, urlResponse) = try await URLSession.shared.data(for: request)
        guard let httpResponse = urlResponse as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return publicURL
    }

    private func compressedImageData(from data: Data) -> Data {
        guard let image = UIImage(data: data),
              let jpegData = image.jpegData(compressionQuality: 0.82)
        else { return data }
        return jpegData
    }

    private func splitName(_ name: String) -> (first: String, last: String) {
        let parts = name.split(separator: " ", omittingEmptySubsequences: true)
        guard let first = parts.first else { return (name, "") }
        let last = parts.dropFirst().joined(separator: " ")
        return (String(first), last)
    }

    private static func savedAvatarURL(for user: User) -> URL? {
        guard let avatarUrl = user.avatarUrl else { return nil }
        return URL(string: avatarUrl)
    }
}

struct ContactHistoryItem: Identifiable {
    let id = UUID()
    let date = Date()
    let field: String
    let oldValue: String
}

struct ProfileInfoRow: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let icon: String
}

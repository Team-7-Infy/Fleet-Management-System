import Foundation
import SwiftUI
import Combine
import Supabase

@MainActor
final class DriverProfileViewModel: ObservableObject {
    private let services: AppServices
    private let driver: Driver?
    private var user: User

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

    let dateOfJoining: String
    let licenseNumber: String
    let aadharNumber: String
    let assignedVehicle: String
    let status: String

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
        licenseNumber = driver?.licenceNum ?? "DL-2024-987654"
        aadharNumber = user.aadhar
        assignedVehicle = driver?.vehicleType ?? "Truck"
        status = (driver?.status ?? .active).rawValue.capitalized
    }

    func loadStats() async {
        guard let driverId = driver?.id else { return }
        do {
            let trips = try await services.tripService.fetchTrips(forDriverId: driverId)
            let completed = trips.filter { $0.status == .completed }
            await MainActor.run {
                completedTrips = completed.count
                totalTrips = "\(trips.count)"
                onTimeRate = trips.isEmpty ? "0%" : "\(Int(Double(completed.count) / Double(trips.count) * 100))%"
                if let last = trips.max(by: { ($0.startTime) < ($1.startTime) }) {
                    let f = DateFormatter()
                    f.dateFormat = "dd MMM, yyyy"
                    lastTripDate = f.string(from: last.startTime)
                }
            }
        } catch {
            print("Failed to load trips: \(error)")
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
        let path = "profile-avatars/\(user.id.uuidString)/avatar-\(Int(Date().timeIntervalSince1970)).jpg"
        let storage = services.supabase.client.storage.from("maintenance")

        try await storage.upload(
            path,
            data: uploadData,
            options: FileOptions(contentType: "image/jpeg")
        )

        return try storage.getPublicURL(path: path).absoluteString
    }

    private func compressedImageData(from data: Data) -> Data {
        guard let image = UIImage(data: data),
              let jpegData = image.jpegData(compressionQuality: 0.82)
        else {
            return data
        }

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

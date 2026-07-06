import Foundation
import SwiftUI
import Combine

final class ManagerProfileViewModel: ObservableObject {
    private let services: AppServices
    @Published var user: User

    @Published var driverName: String
    @Published var phone: String
    @Published var email: String
    @Published var address: String
    @Published var contactHistory: [ContactHistoryItem] = []
    @Published var profileImageData: Data? = nil

    // Statistics for the Manager Overview card
    @Published var totalVehicles: Int = 0
    @Published var totalDrivers: Int = 0
    @Published var activeTripsCount: Int = 0
    @Published var totalTripsCount: Int = 0
    @Published var activeTripRatio: Int = 0
    @Published var lastTripDate: String = "N/A"

    let dateOfJoining: String
    let managerId: String

    init(services: AppServices, user: User) {
        self.services = services
        self.user = user

        driverName = "\(user.fName) \(user.lName)"
        phone = String(user.contact)
        email = user.email
        address = user.address

        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM, yyyy"
        dateOfJoining = formatter.string(from: user.createdAt)
        managerId = String(user.id.uuidString.prefix(8)).uppercased()
    }

    func loadStats() async {
        do {
            async let trips = services.tripService.fetchTrips()
            async let vehicles = services.vehicleService.fetchVehicles()
            async let users = services.userManagementService.fetchUsers()

            let allTrips = try await trips
            let allVehicles = try await vehicles
            let allUsers = try await users

            let activeTrips = allTrips.filter { $0.status == .accepted || $0.status == .inProgress }
            let driversCount = allUsers.filter { $0.role == .driver }.count

            await MainActor.run {
                self.totalVehicles = allVehicles.count
                self.totalDrivers = driversCount
                self.activeTripsCount = activeTrips.count
                self.totalTripsCount = allTrips.count
                self.activeTripRatio = allTrips.isEmpty ? 0 : Int(Double(activeTrips.count) / Double(allTrips.count) * 100)

                if let lastTrip = allTrips.max(by: { $0.startTime < $1.startTime }) {
                    let f = DateFormatter()
                    f.dateFormat = "dd MMM, yyyy"
                    self.lastTripDate = f.string(from: lastTrip.startTime)
                } else {
                    self.lastTripDate = "N/A"
                }
            }
        } catch {
            print("Failed to load manager statistics: \(error)")
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

    @MainActor
    func updateProfile(newName: String, newPhone: String, newEmail: String, newAddress: String, newProfileImageData: Data?) async throws {
        // Validation using UserProfileValidation defined in User.swift
        guard UserProfileValidation.isValidName(newName) else {
            throw AppError.unknown("First name and Last name must contain only alphabetic characters.")
        }
        guard UserProfileValidation.isValidContact(newPhone) else {
            throw AppError.unknown("Phone number must be exactly 10 digits and start with 6, 7, 8, or 9.")
        }
        guard UserProfileValidation.isValidEmail(newEmail) else {
            throw AppError.unknown("Please enter a valid email address.")
        }
        guard UserProfileValidation.isValidAddress(newAddress) else {
            throw AppError.unknown("Address cannot be empty.")
        }

        // Detect contact history changes
        if newName != driverName {
            contactHistory.insert(ContactHistoryItem(field: "Name", oldValue: driverName), at: 0)
        }
        if newPhone != phone {
            contactHistory.insert(ContactHistoryItem(field: "Mobile", oldValue: phone), at: 0)
        }
        if newEmail != email {
            contactHistory.insert(ContactHistoryItem(field: "Email", oldValue: email), at: 0)
        }
        if newAddress != address {
            contactHistory.insert(ContactHistoryItem(field: "Address", oldValue: address), at: 0)
        }

        let nameParts = newName.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            .map(String.init)
        
        let first = nameParts.first ?? ""
        let last = nameParts.count > 1 ? nameParts[1] : ""

        var updatedUser = user
        updatedUser.fName = first
        updatedUser.lName = last
        updatedUser.contact = Int64(newPhone) ?? user.contact
        updatedUser.email = newEmail
        updatedUser.address = newAddress

        // Call database update
        let savedUser = try await services.userManagementService.updateUser(updatedUser)

        self.user = savedUser
        self.driverName = "\(savedUser.fName) \(savedUser.lName)"
        self.phone = String(savedUser.contact)
        self.email = savedUser.email
        self.address = savedUser.address
        
        if let imageData = newProfileImageData {
            self.profileImageData = imageData
        }

        NotificationCenter.default.post(name: NSNotification.Name("UserProfileUpdated"), object: nil)
    }
}

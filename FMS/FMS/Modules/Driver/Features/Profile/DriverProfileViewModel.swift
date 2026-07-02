import Foundation
import SwiftUI
import Combine

final class DriverProfileViewModel: ObservableObject {
    private let services: AppServices
    private let driver: Driver?
    private let user: User

    @Published var driverName: String
    @Published var phone: String
    @Published var email: String
    @Published var address: String
    @Published var contactHistory: [ContactHistoryItem] = []
    @Published var profileImageData: Data? = nil

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

    func updateProfile(newName: String, newPhone: String, newEmail: String, newAddress: String, newProfileImageData: Data?) {
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
        if newProfileImageData != profileImageData {
            profileImageData = newProfileImageData
        }
    }
}

struct ContactHistoryItem: Identifiable, Codable {
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

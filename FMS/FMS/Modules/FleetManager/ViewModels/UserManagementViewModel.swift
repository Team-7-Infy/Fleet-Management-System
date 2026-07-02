import Foundation
import Combine

@MainActor
final class UserManagementViewModel: ObservableObject {
    @Published private(set) var users: [User] = []
    @Published private(set) var drivers: [Driver] = []
    @Published private(set) var maintenancePersonnel: [MaintenancePersonnel] = []
    @Published private(set) var fleetManagers: [FleetManager] = []
    @Published var isLoading = false
    @Published var successMessage: String?
    @Published var errorMessage: String?

    private let service: UserManagementServiceProtocol
    private let authService: AuthServiceProtocol

    init(service: UserManagementServiceProtocol, authService: AuthServiceProtocol) {
        self.service = service
        self.authService = authService
    }

    var activeUsers: [User] {
        users.filter(\.isActive)
    }

    var driverUsers: [User] {
        usersForRole(.driver)
    }

    var maintenanceUsers: [User] {
        usersForRole(.maintenancePersonnel)
    }

    var managerUsers: [User] {
        usersForRole(.fleetManager)
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let fetchedUsers = service.fetchUsers()
            async let fetchedDrivers = service.fetchDrivers()
            async let fetchedMaintenance = service.fetchMaintenancePersonnel()
            async let fetchedFleetManagers = service.fetchFleetManagers()

            users = try await fetchedUsers
            drivers = try await fetchedDrivers
            maintenancePersonnel = try await fetchedMaintenance
            fleetManagers = try await fetchedFleetManagers
            errorMessage = nil
        } catch is CancellationError {
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createUser(form: FleetManagerUserForm) async -> Bool {
        guard form.isValid else {
            errorMessage = "Complete all required user fields."
            successMessage = nil
            return false
        }

        do {
            let password = Self.generateRandomPassword()
            let displayName = form.normalizedName
            let authUserId = try await authService.inviteUser(
                email: form.email,
                password: password,
                displayName: displayName
            )

            let createdUser = try await service.createUser(form.makeUser(id: authUserId))

            switch createdUser.role {
            case .driver:
                let licenceNumber = form.licenceNumber.trimmingCharacters(in: .whitespacesAndNewlines)
                let vehicleType = form.vehicleType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let driver = Driver(
                    id: UUID(),
                    licenceNum: licenceNumber.isEmpty ? "Pending" : licenceNumber,
                    vehicleType: vehicleType.isEmpty ? "van" : vehicleType,
                    status: .active,
                    userId: createdUser.id
                )
                _ = try await service.createDriver(driver)

            case .maintenancePersonnel:
                let personnel = MaintenancePersonnel(
                    id: UUID(),
                    status: .active,
                    userId: createdUser.id
                )
                _ = try await service.createMaintenancePersonnel(personnel)

            case .fleetManager:
                let manager = FleetManager(id: UUID(), userId: createdUser.id)
                _ = try await service.createFleetManager(manager)
            }

            successMessage = "\(createdUser.displayName) added. An invitation email has been sent to \(form.email)."
            errorMessage = nil
            await load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            successMessage = nil
            return false
        }
    }

    private static func generateRandomPassword() -> String {
        let upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let lower = "abcdefghijklmnopqrstuvwxyz"
        let digits = "0123456789"
        let special = "!@#$%^&*"
        let all = upper + lower + digits + special
        var password = ""
        password.append(upper.randomElement()!)
        password.append(lower.randomElement()!)
        password.append(digits.randomElement()!)
        password.append(special.randomElement()!)
        password += String((0..<8).map { _ in all.randomElement()! })
        return String(password.shuffled())
    }

    func updateUser(_ user: User) async -> Bool {
        do {
            _ = try await service.updateUser(user)
            if let index = users.firstIndex(where: { $0.id == user.id }) {
                users[index] = user
            }
            successMessage = "\(user.displayName) updated."
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            successMessage = nil
            return false
        }
    }

    func updateDriverProfile(userId: UUID, licenceNumber: String, vehicleType: String) async -> Bool {
        do {
            let trimmedLicence = licenceNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedVehicleType = vehicleType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            try await service.updateDriverProfile(
                userId: userId,
                licenceNumber: trimmedLicence.isEmpty ? "Pending" : trimmedLicence,
                vehicleType: trimmedVehicleType.isEmpty ? "van" : trimmedVehicleType
            )
            await load()
            successMessage = "Driver profile updated."
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            successMessage = nil
            return false
        }
    }

    func deleteUser(_ user: User) async -> Bool {
        do {
            switch user.role {
            case .driver:
                try await service.deleteDriverByUserId(id: user.id)
            case .maintenancePersonnel:
                try await service.deleteMaintenancePersonnelByUserId(id: user.id)
            case .fleetManager:
                try await service.deleteFleetManagerByUserId(id: user.id)
            }
            try await service.deleteUser(id: user.id)
            try await authService.deleteUserAuth(userId: user.id)
            users.removeAll { $0.id == user.id }
            successMessage = "\(user.displayName) deleted."
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            successMessage = nil
            return false
        }
    }

    func user(for id: UUID?) -> User? {
        guard let id else { return nil }
        return users.first { $0.id == id }
    }

    func managerId(for userId: UUID) -> UUID? {
        fleetManagers.first { $0.userId == userId }?.id
    }

    func driver(for id: UUID?) -> Driver? {
        guard let id else { return nil }
        return drivers.first { $0.id == id }
    }

    func driverUser(for driverId: UUID?) -> User? {
        guard let driver = driver(for: driverId) else { return nil }
        return user(for: driver.userId)
    }

    func personnelUser(for personnelId: UUID?) -> User? {
        guard let personnelId,
              let personnel = maintenancePersonnel.first(where: { $0.id == personnelId })
        else {
            return nil
        }
        return user(for: personnel.userId)
    }

    func usersForRole(_ role: UserRole) -> [User] {
        users
            .filter { $0.role == role }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
}

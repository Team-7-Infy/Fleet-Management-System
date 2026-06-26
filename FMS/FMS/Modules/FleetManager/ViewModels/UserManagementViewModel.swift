import Foundation
import Combine

@MainActor
final class UserManagementViewModel: ObservableObject {
    @Published private(set) var users: [User] = []
    @Published private(set) var drivers: [Driver] = []
    @Published private(set) var maintenancePersonnel: [MaintenancePersonnel] = []
    @Published var isLoading = false
    @Published var successMessage: String?
    @Published var errorMessage: String?

    private let service: UserManagementServiceProtocol

    init(service: UserManagementServiceProtocol) {
        self.service = service
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

            users = try await fetchedUsers
            drivers = try await fetchedDrivers
            maintenancePersonnel = try await fetchedMaintenance
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
            let createdUser = try await service.createUser(form.makeUser())

            switch createdUser.role {
            case .driver:
                let driver = Driver(
                    id: UUID(),
                    licenceNum: form.licenceNumber.trimmingCharacters(in: .whitespacesAndNewlines),
                    vehicleType: form.vehicleType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
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
                break
            }

            successMessage = "\(createdUser.displayName) added."
            errorMessage = nil
            await load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            successMessage = nil
            return false
        }
    }

    func setActive(_ user: User, isActive: Bool) async {
        do {
            try await service.setUserActive(id: user.id, isActive: isActive)
            if let index = users.firstIndex(where: { $0.id == user.id }) {
                users[index].isActive = isActive
            }
            successMessage = "\(user.displayName) \(isActive ? "activated" : "deactivated")."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            successMessage = nil
        }
    }

    func user(for id: UUID?) -> User? {
        guard let id else { return nil }
        return users.first { $0.id == id }
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

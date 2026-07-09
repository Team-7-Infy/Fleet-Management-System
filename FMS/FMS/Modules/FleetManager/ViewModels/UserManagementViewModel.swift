import Foundation
import Combine

@MainActor
final class UserManagementViewModel: ObservableObject {
    @Published private(set) var users: [User] = []
    @Published private(set) var drivers: [Driver] = []
    @Published private(set) var maintenancePersonnel: [MaintenancePersonnel] = []
    @Published private(set) var fleetManagers: [FleetManager] = []
    @Published private(set) var driverScores: [DriverScore] = []
    @Published var isLoading = false
    @Published var successMessage: String?
    @Published var errorMessage: String?
    @Published var unavailableUserIds: Set<UUID> = []

    func toggleUserUnavailable(userId: UUID) {
        if unavailableUserIds.contains(userId) {
            unavailableUserIds.remove(userId)
        } else {
            unavailableUserIds.insert(userId)
        }
    }

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

    func load(trips: [Trip] = [], tasks: [MaintenanceTask] = []) async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let fetchedUsers = service.fetchUsers()
            async let fetchedDrivers = service.fetchDrivers()
            async let fetchedMaintenance = service.fetchMaintenancePersonnel()
            async let fetchedFleetManagers = service.fetchFleetManagers()
            async let fetchedScores = service.fetchAllDriverScores()

            let loadedUsers = try await fetchedUsers
            var loadedDrivers = try await fetchedDrivers
            var loadedMaintenance = try await fetchedMaintenance

            // Sync status column in database for drivers — collect then bulk
            var driverUpdates: [(driverId: UUID, status: String)] = []
            for i in 0..<loadedDrivers.count {
                let driver = loadedDrivers[i]
                guard let user = loadedUsers.first(where: { $0.id == driver.userId }) else { continue }
                
                let calculatedTag: String
                if unavailableUserIds.contains(user.id) {
                    calculatedTag = "unavailable"
                } else {
                    let driverTrips = trips.filter { $0.driverId == driver.id }
                    let hasActiveTrip = driverTrips.contains { $0.status == .accepted || $0.status == .inProgress }
                    if hasActiveTrip {
                        calculatedTag = "on_trip"
                    } else {
                        let hasScheduledTrip = driverTrips.contains { $0.status == .scheduled || $0.status == .pending || $0.status == .rejectionPending }
                        if hasScheduledTrip {
                            calculatedTag = "scheduled"
                        } else {
                            calculatedTag = "available"
                        }
                    }
                }
                
                if driver.status.rawValue != calculatedTag {
                    driverUpdates.append((driverId: driver.id, status: calculatedTag))
                    if let personnelStatus = PersonnelStatus(rawValue: calculatedTag) {
                        loadedDrivers[i].status = personnelStatus
                    }
                }
            }

            if !driverUpdates.isEmpty {
                try? await service.bulkUpdateDriverStatuses(updates: driverUpdates)
            }

            // Sync status column in database for maintenance personnel — collect then bulk
            var personnelUpdates: [(personnelId: UUID, status: String)] = []
            for i in 0..<loadedMaintenance.count {
                let personnel = loadedMaintenance[i]
                guard let user = loadedUsers.first(where: { $0.id == personnel.userId }) else { continue }
                
                let calculatedTag: String
                if unavailableUserIds.contains(user.id) {
                    calculatedTag = "unavailable"
                } else {
                    let hasActiveWork = tasks.contains { $0.executedBy == personnel.id && $0.status == .inProgress }
                    if hasActiveWork {
                        calculatedTag = "in_service"
                    } else {
                        calculatedTag = "available"
                    }
                }
                
                if personnel.status.rawValue != calculatedTag {
                    personnelUpdates.append((personnelId: personnel.id, status: calculatedTag))
                    if let personnelStatus = PersonnelStatus(rawValue: calculatedTag) {
                        loadedMaintenance[i].status = personnelStatus
                    }
                }
            }

            if !personnelUpdates.isEmpty {
                try? await service.bulkUpdateMaintenancePersonnelStatuses(updates: personnelUpdates)
            }

            let activeUserIds = Set(loadedUsers.map(\.id))
            users = loadedUsers
            drivers = loadedDrivers.filter { activeUserIds.contains($0.userId) }
            maintenancePersonnel = loadedMaintenance.filter { activeUserIds.contains($0.userId) }
            fleetManagers = (try await fetchedFleetManagers).filter { activeUserIds.contains($0.userId) }
            driverScores = try await fetchedScores
            errorMessage = nil
        } catch is CancellationError {
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func recalculateAndReloadScores() async {
        for driver in drivers {
            _ = try? await service.calculateAndUpsertDriverScore(driverId: driver.id)
        }
        driverScores = (try? await service.fetchAllDriverScores()) ?? []
    }

    func backfillMissingScores() async -> Int {
        guard let count = try? await service.backfillMissingDriverScores() else { return 0 }
        driverScores = (try? await service.fetchAllDriverScores()) ?? []
        return count
    }

    func driverScore(for driverId: UUID) -> DriverScore? {
        driverScores.first { $0.driverId == driverId }
    }

    var averageDriverScore: Double {
        let scores = driverScores.map(\.overallScore)
        guard !scores.isEmpty else { return 0 }
        return scores.reduce(0, +) / Double(scores.count)
    }

    func createUser(form: FleetManagerUserForm) async -> Bool {
        if let issue = form.validationIssues.first {
            errorMessage = issue.message
            successMessage = nil
            return false
        }

        do {
            let password = Self.generateRandomPassword()
            let displayName = form.normalizedName
            let authUserId = try await authService.inviteUser(
                email: form.normalizedEmail,
                password: password,
                displayName: displayName
            )

            let createdUser = try await service.createUser(form.makeUser(id: authUserId))

            switch createdUser.role {
            case .driver:
                let licenceNumber = form.normalizedLicenceNumber
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
                let rate = Double(form.hourlyRate) ?? 500.0
                let personnel = MaintenancePersonnel(
                    id: UUID(),
                    status: .active,
                    userId: createdUser.id,
                    hourlyRate: rate
                )
                _ = try await service.createMaintenancePersonnel(personnel)

            case .fleetManager:
                let manager = FleetManager(id: UUID(), userId: createdUser.id)
                _ = try await service.createFleetManager(manager)
            }

            successMessage = "\(createdUser.displayName) added. An invitation email has been sent to \(form.normalizedEmail)."
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
            let updated = try await service.updateUser(user)
            if let index = users.firstIndex(where: { $0.id == user.id }) {
                users[index] = updated
            }
            successMessage = "\(updated.displayName) updated."
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
            let trimmedLicence = UserProfileValidation.normalizedLicenceNumber(licenceNumber)
            if trimmedLicence.isEmpty == false,
               UserProfileValidation.isValidLicenceNumber(trimmedLicence) == false {
                errorMessage = "Licence must look like DL-042026-7101 or MH12 2026 1234567."
                successMessage = nil
                return false
            }

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

import Foundation
import Combine

final class ProfileViewModel: ObservableObject {
    @Published private(set) var userProfile: UserProfile?
    @Published private(set) var state: LoadableState<Void> = .idle

    // Statistics for the Performance Card
    @Published var completedWorkOrdersCount: Int = 0
    @Published var activeWorkOrdersCount: Int = 0
    @Published var totalWorkOrdersCount: Int = 0
    @Published var completionRate: Int = 0
    @Published var nextDueJobDate: String = "N/A"

    private let authService: any AuthServicing
    private let workOrderService: any WorkOrderServicing

    init(dependencies: AppDependencyContainer) {
        authService = dependencies.authService
        workOrderService = dependencies.workOrderService
    }

    func load() async {
        state = .loading
        do {
            userProfile = try await authService.currentUser()
            state = .loaded(())
            await loadStats()
        } catch let error as AppError {
            state = .failed(error)
        } catch {
            state = .failed(.unknown(error.localizedDescription))
        }
    }
    
    func loadStats() async {
        guard let personnelId = userProfile?.personnelId else { return }
        do {
            let allWorkOrders = try await workOrderService.assignedWorkOrders()
            let assignedOrders = allWorkOrders.filter { $0.executedBy == personnelId }
            
            let completed = assignedOrders.filter { $0.status == .completed || $0.status == .fake }
            let active = assignedOrders.filter { $0.status == .pending || $0.status == .assigned || $0.status == .inProgress }
            
            await MainActor.run {
                self.completedWorkOrdersCount = completed.count
                self.activeWorkOrdersCount = active.count
                self.totalWorkOrdersCount = assignedOrders.count
                self.completionRate = assignedOrders.isEmpty ? 0 : Int(Double(completed.count) / Double(assignedOrders.count) * 100)
                
                if let nextOrder = active.min(by: { $0.dueDate < $1.dueDate }) {
                    let f = DateFormatter()
                    f.dateFormat = "dd MMM, yyyy"
                    self.nextDueJobDate = f.string(from: nextOrder.dueDate)
                } else {
                    self.nextDueJobDate = "N/A"
                }
            }
        } catch {
            print("Failed to load work orders stats: \(error)")
        }
    }
    
    func updateProfileImage(with data: Data) async {
        do {
            userProfile = try await authService.updateProfileImage(data: data)
            // Post notification to let Dashboard know to refresh
            NotificationCenter.default.post(name: NSNotification.Name("UserProfileUpdated"), object: nil)
        } catch {
            print("Failed to update profile image: \(error)")
        }
    }
    
    @Published var editFirstName: String = ""
    @Published var editLastName: String = ""
    @Published var editContact: String = ""
    @Published var editAddress: String = ""
    @Published var validationError: String?
    
    func populateEditFields() {
        guard let user = userProfile else { return }
        editFirstName = user.f_name ?? ""
        editLastName = user.l_name ?? ""
        editContact = user.contact != nil ? String(user.contact!) : ""
        editAddress = user.addressStr ?? ""
        validationError = nil
    }
    
    private func validateEditFields() -> Bool {
        // Name validation (only alphabets, no numbers)
        let nameRegex = "^[A-Za-z]+$"
        let namePredicate = NSPredicate(format: "SELF MATCHES %@", nameRegex)
        
        if !editFirstName.isEmpty && !namePredicate.evaluate(with: editFirstName) {
            validationError = "First name must contain only alphabetic characters."
            return false
        }
        if !editLastName.isEmpty && !namePredicate.evaluate(with: editLastName) {
            validationError = "Last name must contain only alphabetic characters."
            return false
        }
        
        // Contact validation (exactly 10 digits, starts with 6-9)
        let phoneRegex = "^[6-9][0-9]{9}$"
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        
        if !phonePredicate.evaluate(with: editContact) {
            validationError = "Phone number must be exactly 10 digits and start with 6, 7, 8, or 9."
            return false
        }
        
        // Address validation
        if editAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            validationError = "Address cannot be empty."
            return false
        }
        
        validationError = nil
        return true
    }
    
    @MainActor
    func updateProfileDetails() async throws {
        guard validateEditFields() else {
            throw AppError.unknown(validationError ?? "Invalid input")
        }
        
        let contact = Int64(editContact) // Convert to Int64 if valid
        userProfile = try await authService.updateProfile(firstName: editFirstName, lastName: editLastName, contact: contact, address: editAddress)
        NotificationCenter.default.post(name: NSNotification.Name("UserProfileUpdated"), object: nil)
        await loadStats()
    }

    @MainActor
    func updateProfile(firstName: String, lastName: String, contact: String, address: String, newProfileImageData: Data?) async throws {
        self.editFirstName = firstName
        self.editLastName = lastName
        self.editContact = contact
        self.editAddress = address
        
        if let data = newProfileImageData {
            await updateProfileImage(with: data)
        }
        
        try await updateProfileDetails()
    }
}

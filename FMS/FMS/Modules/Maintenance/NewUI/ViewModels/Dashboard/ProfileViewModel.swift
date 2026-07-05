import Foundation
import Combine

final class ProfileViewModel: ObservableObject {
    @Published private(set) var userProfile: UserProfile?
    @Published private(set) var state: LoadableState<Void> = .idle

    private let authService: any AuthServicing

    init(dependencies: AppDependencyContainer) {
        authService = dependencies.authService
    }

    func load() async {
        state = .loading
        do {
            userProfile = try await authService.currentUser()
            state = .loaded(())
        } catch let error as AppError {
            state = .failed(error)
        } catch {
            state = .failed(.unknown(error.localizedDescription))
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
    }
}

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
}

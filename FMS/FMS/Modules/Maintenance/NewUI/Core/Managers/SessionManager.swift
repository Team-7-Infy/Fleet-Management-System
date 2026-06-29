import Foundation

final class SessionManager {
    private(set) var currentUser: UserProfile?

    func update(user: UserProfile?) {
        currentUser = user
    }
}

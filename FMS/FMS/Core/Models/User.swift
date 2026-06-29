import Foundation

struct User: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var email: String
    var aadhar: String
    var contact: Int64
    var role: UserRole
    var fName: String
    var lName: String
    var address: String
    var isActive: Bool
    var createdAt: Date
    var avatarUrl: String? = nil
    var firstTimeLogin: Bool = true

    enum CodingKeys: String, CodingKey {
        case id = "userid"
        case email
        case aadhar
        case contact
        case role
        case fName = "f_name"
        case lName = "l_name"
        case address
        case isActive = "isactive"
        case createdAt = "createdat"
        case avatarUrl = "avatarurl"
        case firstTimeLogin = "first_time_login"
    }

}

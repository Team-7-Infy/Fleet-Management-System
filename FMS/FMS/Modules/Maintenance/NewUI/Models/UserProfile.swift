import Foundation

struct UserProfile: Identifiable, Codable, Hashable {
    let id: UUID
    let email: String
    let aadhar: String?
    let contact: Int64?
    let role: String?
    let f_name: String?
    let l_name: String?
    let addressStr: String?
    let isactive: Bool?
    let createdat: Date?
    let avatarurl: String?
    let first_time_login: Bool?
    var personnelId: UUID?
    
    // UI Local State (Not in DB, mapped separately or handled locally)
    var profileImageData: Data?
    
    enum CodingKeys: String, CodingKey {
        case id = "userid"
        case email
        case aadhar
        case contact
        case role
        case f_name
        case l_name
        case addressStr = "address"
        case isactive
        case createdat
        case avatarurl
        case first_time_login
        case personnelId = "personnelid"
    }
    
    // UI Helpers for backward compatibility during refactor
    var name: String { "\(f_name ?? "") \(l_name ?? "")".trimmingCharacters(in: .whitespaces) }
    var fullName: String { name }
    var contactNumber: String { contact != nil ? String(contact!) : "Not provided" }
    var address: String { addressStr ?? "Not provided" }
    var aadhaarNumber: String { aadhar ?? "N/A" }
    var status: String { isactive == true ? "Active" : "Inactive" }
}

import Foundation

extension User {
    func toUserProfile() -> UserProfile {
        UserProfile(
            id: id,
            email: email,
            aadhar: aadhar.isEmpty ? nil : aadhar,
            contact: contact == 0 ? nil : contact,
            role: role.rawValue,
            f_name: fName.isEmpty ? nil : fName,
            l_name: lName.isEmpty ? nil : lName,
            addressStr: address.isEmpty ? nil : address,
            isactive: isActive,
            createdat: createdAt,
            avatarurl: avatarUrl,
            first_time_login: firstTimeLogin,
            personnelId: nil
        )
    }
}

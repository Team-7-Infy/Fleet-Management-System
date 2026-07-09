import Foundation

extension UUID {
    var uuidLowercased: String {
        uuidString.lowercased()
    }

    /// 8-char uppercase hex fragment used as the base for all short display IDs.
    var shortCode: String {
        String(uuidString.prefix(8)).uppercased()
    }

    /// Legacy "#XXXXXXXX" short form. Used only by cleaningUUIDs to redact
    /// raw UUIDs embedded in free-text fields (incident/inspection descriptions).
    /// Entity display IDs (trip/user/work order) should use displayId(_:) instead.
    var shortIdentifier: String {
        "#" + shortCode
    }
}

/// Prefixes used to disambiguate short display IDs across entity types.
/// User covers all roles (fleet manager, driver, maintenance personnel —
/// same table), so the prefix is USR, not role-specific; the surrounding
/// UI label (e.g. "Personnel ID") already conveys the role.
enum EntityPrefix: String {
    case trip = "TRP"
    case user = "USR"
    case workOrder = "WO"
}

extension UUID {
    /// Canonical short display ID: "<PREFIX>-<8 uppercase hex chars>".
    /// e.g. TRP-A1B2C3D4, USR-9F00E211, WO-4C77B120.
    func displayId(_ kind: EntityPrefix) -> String {
        "\(kind.rawValue)-\(shortCode)"
    }
}

extension String {
    var cleaningUUIDs: String {
        let pattern = "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return self }
        
        let nsString = self as NSString
        let matches = regex.matches(in: self, options: [], range: NSRange(location: 0, length: nsString.length))
        
        var result = self
        for match in matches.reversed() {
            let uuidRange = match.range
            let uuidStr = nsString.substring(with: uuidRange)
            if let uuid = UUID(uuidString: uuidStr) {
                result = (result as NSString).replacingCharacters(in: uuidRange, with: uuid.shortIdentifier)
            }
        }
        return result
    }
}

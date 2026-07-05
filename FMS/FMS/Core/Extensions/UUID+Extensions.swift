import Foundation

extension UUID {
    var uuidLowercased: String {
        uuidString.lowercased()
    }
    
    var shortIdentifier: String {
        let str = uuidString
        if str.contains("-0000-0000-0000-") {
            let suffix = str.suffix(12)
            if let number = Int(suffix, radix: 16) {
                return String(format: "#%04d", number)
            }
        }
        return "#" + str.prefix(8).uppercased()
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

import Foundation

@propertyWrapper
struct DateOnly: Codable, Hashable, Sendable {
    var wrappedValue: Date

    init(wrappedValue: Date) {
        self.wrappedValue = wrappedValue
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let formatter = DateOnly.formatter
        try container.encode(formatter.string(from: wrappedValue))
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        let formatter = DateOnly.formatter
        guard let date = formatter.date(from: string) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected yyyy-MM-dd format, got \(string)"
            )
        }
        wrappedValue = date
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}

struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
    }
    
    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
    
    init(stringValue: String, intValue: Int? = nil) {
        self.stringValue = stringValue
        self.intValue = intValue
    }
}

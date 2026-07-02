import Foundation

let dateStr = "2026-06-29 10:30:00+00"
print("Input: \(dateStr)")

let isoFormatter = ISO8601DateFormatter()
isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
var date: Date? = isoFormatter.date(from: dateStr)
print("ISO with fractions: \(String(describing: date))")

if date == nil {
    let customFormatter = DateFormatter()
    customFormatter.dateFormat = "yyyy-MM-dd HH:mm:ssX"
    customFormatter.timeZone = TimeZone(secondsFromGMT: 0)
    date = customFormatter.date(from: dateStr)
    print("Custom formatter (X): \(String(describing: date))")
}

if date == nil {
    let fallbackFormatter = DateFormatter()
    fallbackFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    fallbackFormatter.timeZone = TimeZone(secondsFromGMT: 0)
    date = fallbackFormatter.date(from: dateStr)
    print("Fallback formatter: \(String(describing: date))")
}

if date == nil {
    let zFormatter = DateFormatter()
    zFormatter.dateFormat = "yyyy-MM-dd HH:mm:ssZZZZZ"
    date = zFormatter.date(from: dateStr)
    print("Z formatter: \(String(describing: date))")
}

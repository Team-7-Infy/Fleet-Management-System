import SwiftUI

enum AppColor {
    static let primary = Color(lightHex: 0xE3F2FD, darkHex: 0x1E293B)
    static let secondary = Color(lightHex: 0xBBDEFB, darkHex: 0x334155)
    static let brand = Color(lightHex: 0x42A5F5, darkHex: 0x3B82F6)
    static let inProgress = brand
    static let background = Color(lightHex: 0xF8FCFF, darkHex: 0x0F172A)
    static let secondaryBackground = primary
    static let surface = Color(lightHex: 0xFFFFFF, darkHex: 0x1E293B)
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let separator = Color(.separator)
    static let success = Color(lightHex: 0x9BCA53, darkHex: 0x4ADE80)
    static let warning = Color(lightHex: 0xFFD746, darkHex: 0xFBBF24)
    static let destructive = Color(lightHex: 0xDB5243, darkHex: 0xF87171)
}

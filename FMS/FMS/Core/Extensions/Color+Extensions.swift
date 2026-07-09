//
//  Color+Extensions.swift
//  FMS
//
//  Created by Veer on 26/06/26.
//
import Foundation
import SwiftUI

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1.0) {
        let red = CGFloat((hex >> 16) & 0xff) / 255
        let green = CGFloat((hex >> 8) & 0xff) / 255
        let blue = CGFloat(hex & 0xff) / 255
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }

    convenience init(lightHex: UInt32, darkHex: UInt32, alpha: CGFloat = 1.0) {
        self.init { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(hex: darkHex, alpha: alpha)
            } else {
                return UIColor(hex: lightHex, alpha: alpha)
            }
        }
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(uiColor: UIColor(hex: hex, alpha: CGFloat(alpha)))
    }

    init(lightHex: UInt32, darkHex: UInt32, alpha: Double = 1.0) {
        self.init(uiColor: UIColor(lightHex: lightHex, darkHex: darkHex, alpha: CGFloat(alpha)))
    }
}

//
//  Color+Extensions.swift
//  FMS
//
//  Created by Veer on 26/06/26.
//
import Foundation
import SwiftUI

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let red = Double((hex >> 16) & 0xff) / 255
        let green = Double((hex >> 8) & 0xff) / 255
        let blue = Double(hex & 0xff) / 255
        self.init(red: red, green: green, blue: blue, opacity: alpha)
    }
}

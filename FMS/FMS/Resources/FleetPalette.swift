//
//  FleetPalette.swift
//  FMS
//
//  Created by Veer on 26/06/26.
//


import SwiftUI

enum FleetPalette {
    static let primary = Color(hex: 0x42A5F5)
    static let secondary = Color(hex: 0x90CAF9)
    static let tertiary = Color(hex: 0xBBDEFB)
    static let softBlue = Color(hex: 0xE3F2FD)
    static let background = Color(hex: 0xF8FCFF)
    static let surface = Color.white
    static let textPrimary = Color.black
    static let textSecondary = Color.secondary
    static let textTertiary = Color.secondary.opacity(0.65)
    static let success = Color.green
    static let warning = Color.orange
    static let danger = Color.red
    static let neutral = Color.gray

    static let twoColumnGrid = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    static func vehicleStatus(_ status: VehicleStatus) -> Color {
        switch status {
        case .active:
            return success
        case .inactive:
            return neutral
        case .maintenance:
            return warning
        }
    }

    static func tripStatus(_ status: TripStatus) -> Color {
        switch status {
        case .pending:
            return warning
        case .accepted:
            return secondary
        case .rejected:
            return danger
        case .completed:
            return success
        }
    }

    static func maintenanceStatus(_ status: MaintenanceTaskStatus) -> Color {
        switch status {
        case .scheduled:
            return warning
        case .assigned:
            return secondary
        case .inProgress:
            return primary
        case .completed:
            return success
        }
    }
}
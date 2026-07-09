//
//  FleetPalette.swift
//  FMS
//
//  Created by Veer on 26/06/26.
//


import SwiftUI

enum FleetPalette {
    static let primary = Color(lightHex: 0xE3F2FD, darkHex: 0x1E293B)
    static let secondary = Color(lightHex: 0xBBDEFB, darkHex: 0x334155)
    static let tertiary = Color(lightHex: 0x42A5F5, darkHex: 0x3B82F6)
    static let accent = tertiary
    static let inProgress = Color(hex: 0xFF7A2F)
    static let softBlue = primary
    static let background = Color(lightHex: 0xF8FCFF, darkHex: 0x0F172A)
    static let surface = Color(lightHex: 0xFFFFFF, darkHex: 0x1E293B)
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color.secondary.opacity(0.65)
    static let success = Color(lightHex: 0x9BCA53, darkHex: 0x4ADE80)
    static let warning = Color(lightHex: 0xFFD746, darkHex: 0xFBBF24)
    static let danger = Color(lightHex: 0xDB5243, darkHex: 0xF87171)
    static let neutral = Color.gray
    static let miscellaneous = Color.orange

    static let twoColumnGrid = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    static func vehicleStatus(_ status: VehicleStatus) -> Color {
        switch status {
        case .available:
            return success
        case .assigned:
            return accent
        case .inMaintenance:
            return warning
        case .outOfService:
            return secondary
        }
    }

    static func personnelStatus(_ status: PersonnelStatus) -> Color {
        switch status {
        case .active, .available:
            return success
        case .inactive, .unavailable:
            return secondary
        case .onTrip, .inService:
            return inProgress
        case .scheduled:
            return warning
        }
    }

    static func userActive(_ isActive: Bool) -> Color {
        isActive ? success : secondary
    }

    static func tripStatus(_ status: TripStatus) -> Color {
        switch status {
        case .scheduled:
            return warning
        case .pending:
            return warning
        case .accepted:
            return inProgress
        case .rejectionPending:
            return danger
        case .rejected:
            return danger
        case .inProgress:
            return inProgress
        case .completed:
            return success
        case .cancelled:
            return danger
        }
    }

    static func maintenanceStatus(_ status: MaintenanceTaskStatus) -> Color {
        switch status {
        case .scheduled:
            return warning
        case .assigned:
            return inProgress
        case .inProgress:
            return inProgress
        case .onHold:
            return warning
        case .completed:
            return success
        case .verified:
            return success
        case .closed:
            return success
        case .fake:
            return danger
        }
    }
}

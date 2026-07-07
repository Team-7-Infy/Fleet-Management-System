//
//  FleetPalette.swift
//  FMS
//
//  Created by Veer on 26/06/26.
//


import SwiftUI

enum FleetPalette {
    static let primary = Color(hex: 0xE3F2FD)
    static let secondary = Color(hex: 0xBBDEFB)
    static let tertiary = Color(hex: 0x42A5F5)
    static let accent = tertiary
    static let inProgress = tertiary
    static let softBlue = primary
    static let background = Color(hex: 0xF8FCFF)
    static let surface = Color.white
    static let textPrimary = Color.black
    static let textSecondary = Color.secondary
    static let textTertiary = Color.secondary.opacity(0.65)
    static let success = Color(hex: 0x9BCA53)
    static let warning = Color(hex: 0xFFD746)
    static let danger = Color(hex: 0xDB5243)
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
        case .fake:
            return danger
        }
    }
}

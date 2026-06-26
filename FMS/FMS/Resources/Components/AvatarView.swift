//
//  AvatarView.swift
//  FMS
//
//  Created by Veer on 26/06/26.
//

import SwiftUI
struct AvatarView: View {
    var name: String
    var role: UserRole?
    var size: CGFloat = 58
    var imageURL: URL?

    var body: some View {
        ZStack {
            Circle()
                .fill(tint)

            if let imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        initialsView
                    }
                }
            } else {
                initialsView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(.white.opacity(0.82), lineWidth: 2)
        }
        .accessibilityHidden(true)
    }

    private var initialsView: some View {
        Text(initials)
            .font(.system(size: max(13, size * 0.28), weight: .bold))
            .foregroundStyle(.white)
    }

    private var initials: String {
        let parts = name.split(separator: " ").prefix(2).compactMap(\.first)
        let value = String(parts).uppercased()
        return value.isEmpty ? "?" : value
    }

    private var tint: Color {
        switch role {
        case .driver:
            return FleetPalette.primary
        case .maintenancePersonnel:
            return FleetPalette.warning
        case .fleetManager:
            return FleetPalette.secondary
        case nil:
            return FleetPalette.secondary
        }
    }
}

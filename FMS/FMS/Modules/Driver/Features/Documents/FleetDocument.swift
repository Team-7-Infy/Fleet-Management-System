//
//  FleetDocument.swift
//  FMSD
//
//  Created by Dev Jain on 24/06/26.
//


import Foundation

struct FleetDocument: Identifiable {
    let id = UUID()
    let title: String
    let type: DocumentCategory
    let expiryDate: Date
    let documentURL: String?

    var isUploaded: Bool { documentURL != nil }
    
    enum DocumentCategory: String, CaseIterable {
        case driver = "Driver Documents"
    }
    
    var daysRemaining: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: expiryDate)
        return components.day ?? 0
    }
    
    var status: DocumentStatus {
        guard isUploaded else { return .notUploaded }
        if daysRemaining < 0 { return .expired }
        if daysRemaining <= 15 { return .critical }
        if daysRemaining <= 30 { return .warning }
        return .valid
    }
    
    enum DocumentStatus {
        case notUploaded, valid, warning, critical, expired
    }
}
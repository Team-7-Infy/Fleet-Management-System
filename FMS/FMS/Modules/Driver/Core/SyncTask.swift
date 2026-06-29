//
//  SyncTask.swift
//  FMSD
//
//  Created by Dev Jain on 24/06/26.
//


import Foundation

struct SyncTask: Identifiable, Codable {
    var id: UUID = UUID()
    let timestamp: Date
    let endpoint: String
    let httpMethod: String
    let payload: Data? // JSON payload stored as Data
    var retryCount: Int = 0
    
    enum HTTPMethod: String, Codable {
        case POST, PUT, PATCH, DELETE
    }
}
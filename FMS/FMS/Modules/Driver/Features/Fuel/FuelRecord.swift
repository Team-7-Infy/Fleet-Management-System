//
//  FuelRecord.swift
//  FMSD
//
//  Created by Dev Jain on 24/06/26.
//


import Foundation
import Combine

struct FuelRecord: Identifiable {
    let id = UUID()
    let date: Date
    var vehicleId: String
    var fuelType: FuelType
    var amountRequested: Double?
    var cost: Double?
    var volumeFilled: Double? // in Liters or Gallons
    var currentFuelLevel: Double // Percentage 0.0 to 1.0
    var status: RequestStatus
    var receiptImageURL: String?
    
    enum FuelType: String, CaseIterable {
        case diesel = "Diesel"
        case petrol = "Petrol"
        case ev = "Electric Charge"
    }
    
    enum RequestStatus: String {
        case pending = "Pending Approval"
        case approved = "Approved"
        case rejected = "Rejected"
        case completed = "Completed"
    }
}

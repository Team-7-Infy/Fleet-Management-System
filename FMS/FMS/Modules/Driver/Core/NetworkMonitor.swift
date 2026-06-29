//
//  NetworkMonitor.swift
//  FMSD
//
//  Created by Dev Jain on 24/06/26.
//


import Foundation
import Network
import Combine

class NetworkMonitor: ObservableObject {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected: Bool = true
    
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                // Check if the connection is satisfied (we have internet)
                self?.isConnected = path.status == .satisfied
                
                if self?.isConnected == true {
                    // Trigger the Sync Manager when connection is restored
                    OfflineSyncManager.shared.processQueue()
                }
            }
        }
        monitor.start(queue: queue)
    }
}
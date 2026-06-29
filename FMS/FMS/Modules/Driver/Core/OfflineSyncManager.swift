//
//  OfflineSyncManager.swift
//  FMSD
//
//  Created by Dev Jain on 24/06/26.
//


import Foundation
import Combine

class OfflineSyncManager: ObservableObject {
    static let shared = OfflineSyncManager() // Singleton for global access
    
    @Published var pendingTaskCount: Int = 0
    @Published var isSyncing: Bool = false
    
    private let queueKey = "offline_sync_queue"
    
    private init() {
        updatePendingCount()
    }
    
    // MARK: - Enqueue Tasks
    /// Call this instead of making a direct API call when performing critical writes
    func enqueueTask(endpoint: String, method: SyncTask.HTTPMethod, payload: Data?) {
        let newTask = SyncTask(timestamp: Date(), endpoint: endpoint, httpMethod: method.rawValue, payload: payload)
        
        var currentQueue = getQueue()
        currentQueue.append(newTask)
        saveQueue(currentQueue)
        
        // If we are currently online, try to process immediately
        // (Assuming you check NetworkMonitor.isConnected here)
        processQueue()
    }
    
    // MARK: - Process Queue
    func processQueue() {
        var currentQueue = getQueue()
        guard !currentQueue.isEmpty && !isSyncing else { return }
        
        isSyncing = true
        
        // Sort by timestamp to ensure chronological execution
        currentQueue.sort { $0.timestamp < $1.timestamp }
        
        // In a real enterprise app, you would use URLSession to process these.
        // We will simulate the batch processing here.
        let group = DispatchGroup()
        var successfulTaskIds: Set<UUID> = []
        
        for task in currentQueue {
            group.enter()
            
            // SIMULATED API CALL
            print("🔄 Syncing Task: \(task.httpMethod) \(task.endpoint)")
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                // On HTTP 200 OK:
                successfulTaskIds.insert(task.id)
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            // Remove successful tasks from the local queue
            let remainingQueue = currentQueue.filter { !successfulTaskIds.contains($0.id) }
            self.saveQueue(remainingQueue)
            self.isSyncing = false
            print("✅ Sync Complete. \(remainingQueue.count) tasks remaining.")
        }
    }
    
    // MARK: - Local Storage Helpers (Using UserDefaults for demonstration)
    // *Note: For heavy payloads (like photos), use CoreData or FileManager.*
    private func getQueue() -> [SyncTask] {
        guard let data = UserDefaults.standard.data(forKey: queueKey),
              let queue = try? JSONDecoder().decode([SyncTask].self, from: data) else {
            return []
        }
        return queue
    }
    
    private func saveQueue(_ queue: [SyncTask]) {
        if let data = try? JSONEncoder().encode(queue) {
            UserDefaults.standard.set(data, forKey: queueKey)
        }
        DispatchQueue.main.async {
            self.updatePendingCount()
        }
    }
    
    private func updatePendingCount() {
        pendingTaskCount = getQueue().count
    }
}

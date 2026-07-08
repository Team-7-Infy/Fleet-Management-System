import Foundation
import Combine
import Supabase

// MARK: - Threshold Store
/// Manages per-part minimum stock threshold locally and syncs to Supabase.
/// Local cache ensures UI remains responsive while backend updates.
final class ThresholdStore: ObservableObject {

    static let shared = ThresholdStore()

    /// Default threshold applied when no explicit value has been saved.
    static let defaultThreshold = 5

    private let defaults: UserDefaults
    private let keyPrefix = "threshold_"

    @Published private(set) var thresholds: [String: Int] = [:]
    private var supabase: SupabaseServiceProtocol?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Hydrate published dict from UserDefaults so observers fire on launch.
        let all = defaults.dictionaryRepresentation()
        self.thresholds = all
            .filter { $0.key.hasPrefix(keyPrefix) }
            .compactMapValues { $0 as? Int }
            
        // Setup realtime sync or fetch from DB in future if needed
    }

    func configure(supabase: SupabaseServiceProtocol) {
        self.supabase = supabase
    }

    var supabaseClient: SupabaseClient? {
        supabase?.client
    }

    // MARK: - Read

    func threshold(for id: UUID) -> Int {
        thresholds[key(for: id)] ?? Self.defaultThreshold
    }

    func isLowStock(quantity: Int, partID: UUID) -> Bool {
        quantity < threshold(for: partID)
    }

    // MARK: - Write

    func setThreshold(_ value: Int, for id: UUID) {
        let k = key(for: id)
        let clamped = max(0, value)
        
        // Save locally for immediate UI update
        defaults.set(clamped, forKey: k)
        thresholds[k] = clamped
        
        // Save to Supabase backend asynchronously
        guard let supabase = supabase else { return }
        Task {
            do {
                try await supabase.client.from("inventory")
                    .update(["threshold": clamped])
                    .eq("partid", value: id)
                    .execute()
            } catch {
                print("Failed to sync threshold to Supabase for part \(id): \(error)")
            }
        }
    }

    // MARK: - Private

    private func key(for id: UUID) -> String {
        keyPrefix + id.uuidString
    }
}

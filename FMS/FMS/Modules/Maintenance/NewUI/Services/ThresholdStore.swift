import Foundation
import Combine

// MARK: - Threshold Store
/// Persists a per-part minimum stock threshold in UserDefaults.
/// Keyed by part UUID string so values survive app restarts and are
/// independent of CSV reload order.
final class ThresholdStore: ObservableObject {

    static let shared = ThresholdStore()

    /// Default threshold applied when no explicit value has been saved.
    static let defaultThreshold = 5

    private let defaults: UserDefaults
    private let keyPrefix = "threshold_"

    @Published private(set) var thresholds: [String: Int] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Hydrate published dict from UserDefaults so observers fire on launch.
        let all = defaults.dictionaryRepresentation()
        self.thresholds = all
            .filter { $0.key.hasPrefix(keyPrefix) }
            .compactMapValues { $0 as? Int }
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
        defaults.set(clamped, forKey: k)
        thresholds[k] = clamped
    }

    // MARK: - Private

    private func key(for id: UUID) -> String {
        keyPrefix + id.uuidString
    }
}

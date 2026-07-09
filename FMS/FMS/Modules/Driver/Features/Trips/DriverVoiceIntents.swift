import AppIntents
import UIKit

struct SOSIntent: AppIntent {
    static var title: LocalizedStringResource = "Emergency SOS"
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let tripID = await MainActor.run { VoiceActionBridge.shared.activeTripID }
        guard tripID != nil else {
            return .result(dialog: "Open your active trip in FleetMS first, then try SOS again.")
        }
        NotificationCenter.default.post(name: .voiceSOS, object: nil)
        return .result(dialog: "Triggering emergency SOS.")
    }
}

struct PauseResumeTripIntent: AppIntent {
    static var title: LocalizedStringResource = "Pause or Resume Trip"
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let tripID = await MainActor.run { VoiceActionBridge.shared.activeTripID }
        guard tripID != nil else {
            return .result(dialog: "Open your active trip in FleetMS first.")
        }
        NotificationCenter.default.post(name: .voicePauseResume, object: nil)
        return .result(dialog: "Toggling trip pause.")
    }
}

struct RerouteIntent: AppIntent {
    static var title: LocalizedStringResource = "Reroute Trip"
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let tripID = await MainActor.run { VoiceActionBridge.shared.activeTripID }
        guard tripID != nil else {
            return .result(dialog: "Open your active trip in FleetMS first.")
        }
        NotificationCenter.default.post(name: .voiceReroute, object: nil)
        return .result(dialog: "Recalculating your route.")
    }
}

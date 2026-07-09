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
        try await requestConfirmation(
            dialog: IntentDialog("This will alert dispatch and share your location. Trigger emergency SOS?")
        )
        await MainActor.run { VoiceActionBridge.shared.onConfirmedSOS?() }
        return .result(dialog: "Emergency SOS triggered. Dispatch has been alerted.")
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
        try await requestConfirmation(
            dialog: IntentDialog("Recalculate your route from your current location?")
        )
        await MainActor.run { VoiceActionBridge.shared.onConfirmedReroute?() }
        return .result(dialog: "Finding a better route for you.")
    }
}

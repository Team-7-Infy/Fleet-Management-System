import Combine
import Foundation

@MainActor
final class VoiceActionBridge: ObservableObject {
    static let shared = VoiceActionBridge()

    @Published var activeTripID: UUID? = nil
    @Published var openWorkOrderID: WorkOrder.ID? = nil
    @Published var currentVehicleType: String? = nil

    /// Set by ActiveNavigationDetailView onAppear, called by Siri intents after confirmation.
    /// Cleared onDisappear.
    var onConfirmedSOS: (() -> Void)? = nil
    var onConfirmedReroute: (() -> Void)? = nil

    private init() {}
}

extension Notification.Name {
    static let voiceSOS = Notification.Name("voice.sos")
    static let voicePauseResume = Notification.Name("voice.pauseResume")
    static let voiceReroute = Notification.Name("voice.reroute")
    static let voiceAddPart = Notification.Name("voice.addPart")
    static let voiceAddRemark = Notification.Name("voice.addRemark")
}

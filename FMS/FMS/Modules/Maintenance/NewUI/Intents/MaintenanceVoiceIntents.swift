import AppIntents
import UIKit

struct AddPartIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Used Part"
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Part name")
    var partName: String

    @Parameter(title: "Quantity", default: 1)
    var quantity: Int

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let woID = await MainActor.run { VoiceActionBridge.shared.openWorkOrderID }
        guard woID != nil else {
            return .result(dialog: "Open the work order in FleetMS first, then add the part again.")
        }
        NotificationCenter.default.post(name: .voiceAddPart, object: nil, userInfo: ["partName": partName, "quantity": quantity])
        return .result(dialog: "Adding \(quantity) of \(partName).")
    }
}

struct AddRemarkIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Work Order Remark"
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Remark")
    var text: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let woID = await MainActor.run { VoiceActionBridge.shared.openWorkOrderID }
        guard woID != nil else {
            return .result(dialog: "Open the work order in FleetMS first, then add your remark again.")
        }
        NotificationCenter.default.post(name: .voiceAddRemark, object: nil, userInfo: ["text": text])
        return .result(dialog: "Remark added.")
    }
}

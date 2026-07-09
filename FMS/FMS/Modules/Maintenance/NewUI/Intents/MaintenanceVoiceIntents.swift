import AppIntents
import UIKit

struct AddPartIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Used Part"
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Part")
    var part: PartEntity

    @Parameter(title: "Quantity")
    var quantity: Int?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let woID = await MainActor.run { VoiceActionBridge.shared.openWorkOrderID }
        guard woID != nil else {
            return .result(dialog: "Open the work order in FleetMS first, then add the part again.")
        }

        let resolvedQuantity: Int
        if let qty = quantity {
            resolvedQuantity = qty
        } else {
            resolvedQuantity = try await $quantity.requestValue("How many would you like to add?")
        }

        // Validate quantity against available stock
        let available = await MainActor.run { PartEntityCache.shared.availableQuantity(for: part.id) }
        guard resolvedQuantity <= available else {
            return .result(dialog: "Only \(available) in stock. Please add the part manually with a smaller quantity.")
        }

        NotificationCenter.default.post(
            name: .voiceAddPart,
            object: nil,
            userInfo: ["partID": part.id, "quantity": resolvedQuantity]
        )
        return .result(dialog: "Adding \(resolvedQuantity) of \(part.name).")
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

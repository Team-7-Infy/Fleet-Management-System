import AppIntents

struct FMSAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SOSIntent(),
            phrases: [
                "SOS with \(.applicationName)",
                "Emergency with \(.applicationName)"
            ],
            shortTitle: "SOS",
            systemImageName: "exclamationmark.triangle.fill"
        )
        AppShortcut(
            intent: PauseResumeTripIntent(),
            phrases: [
                "Pause my trip with \(.applicationName)",
                "Resume my trip with \(.applicationName)"
            ],
            shortTitle: "Pause Trip",
            systemImageName: "pause.fill"
        )
        AppShortcut(
            intent: RerouteIntent(),
            phrases: [
                "Reroute with \(.applicationName)",
                "Recalculate route with \(.applicationName)"
            ],
            shortTitle: "Reroute",
            systemImageName: "arrow.triangle.turn.up.right.diamond.fill"
        )
        AppShortcut(
            intent: AddPartIntent(),
            phrases: [
                "Add a part with \(.applicationName)"
            ],
            shortTitle: "Add Part",
            systemImageName: "wrench.fill"
        )
        AppShortcut(
            intent: AddRemarkIntent(),
            phrases: [
                "Add a remark with \(.applicationName)"
            ],
            shortTitle: "Add Remark",
            systemImageName: "text.bubble.fill"
        )
    }
}

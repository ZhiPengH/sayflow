import Foundation

enum SelectionHotZonePolicyTests {
    static func triggerButtonUsesSayFlowInitial() throws {
        try expectEqual(SelectionHotZonePresentation.triggerButtonTitle, "S")
    }

    static func showsOnlyForTrustedNonEmptyExternalSelections() throws {
        try expectEqual(
            SelectionHotZonePolicy.decision(
                accessibilityTrusted: true,
                selectedText: "  The market are unpredictable in short-term.  ",
                frontmostBundleIdentifier: "com.apple.TextEdit",
                ownBundleIdentifier: "com.zhixing.sayflow"
            ),
            .show("The market are unpredictable in short-term.")
        )

        try expectEqual(
            SelectionHotZonePolicy.decision(
                accessibilityTrusted: false,
                selectedText: "The market are unpredictable in short-term.",
                frontmostBundleIdentifier: "com.apple.TextEdit",
                ownBundleIdentifier: "com.zhixing.sayflow"
            ),
            .hide
        )

        try expectEqual(
            SelectionHotZonePolicy.decision(
                accessibilityTrusted: true,
                selectedText: "   ",
                frontmostBundleIdentifier: "com.apple.TextEdit",
                ownBundleIdentifier: "com.zhixing.sayflow"
            ),
            .hide
        )

        try expectEqual(
            SelectionHotZonePolicy.decision(
                accessibilityTrusted: true,
                selectedText: "The market are unpredictable in short-term.",
                frontmostBundleIdentifier: "com.zhixing.sayflow",
                ownBundleIdentifier: "com.zhixing.sayflow"
            ),
            .hide
        )
    }
}

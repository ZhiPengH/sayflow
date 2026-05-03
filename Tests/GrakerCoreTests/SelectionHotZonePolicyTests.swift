import Foundation

enum SelectionHotZonePolicyTests {
    static func showsOnlyForTrustedNonEmptyExternalSelections() throws {
        try expectEqual(
            SelectionHotZonePolicy.decision(
                accessibilityTrusted: true,
                selectedText: "  The market are unpredictable in short-term.  ",
                frontmostBundleIdentifier: "com.apple.TextEdit",
                ownBundleIdentifier: "com.zhixing.graker"
            ),
            .show("The market are unpredictable in short-term.")
        )

        try expectEqual(
            SelectionHotZonePolicy.decision(
                accessibilityTrusted: false,
                selectedText: "The market are unpredictable in short-term.",
                frontmostBundleIdentifier: "com.apple.TextEdit",
                ownBundleIdentifier: "com.zhixing.graker"
            ),
            .hide
        )

        try expectEqual(
            SelectionHotZonePolicy.decision(
                accessibilityTrusted: true,
                selectedText: "   ",
                frontmostBundleIdentifier: "com.apple.TextEdit",
                ownBundleIdentifier: "com.zhixing.graker"
            ),
            .hide
        )

        try expectEqual(
            SelectionHotZonePolicy.decision(
                accessibilityTrusted: true,
                selectedText: "The market are unpredictable in short-term.",
                frontmostBundleIdentifier: "com.zhixing.graker",
                ownBundleIdentifier: "com.zhixing.graker"
            ),
            .hide
        )
    }
}

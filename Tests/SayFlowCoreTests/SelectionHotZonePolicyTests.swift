import Foundation

enum SelectionHotZonePolicyTests {
    static func triggerButtonUsesIconInsteadOfTextTitle() throws {
        try expectEqual(SelectionHotZonePresentation.triggerButtonTitle, "")
        try expectEqual(SelectionHotZonePresentation.triggerIconFileName, "icon_32x32@2x.png")
        try expectEqual(SelectionHotZonePresentation.triggerIconPointSize, 20)
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

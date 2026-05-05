import Foundation

enum SelectionHotZonePolicyTests {
    static func triggerButtonUsesIconInsteadOfTextTitle() throws {
        try expectEqual(SelectionHotZonePresentation.triggerButtonTitle, "")
        try expectEqual(SelectionHotZonePresentation.triggerIconFileName, "icon_32x32@2x.png")
        try expectEqual(SelectionHotZonePresentation.triggerIconPointSize, 32)
        try expectEqual(SelectionHotZonePresentation.triggerPanelSideLength, 32)
        try expectEqual(SelectionHotZonePresentation.triggerButtonInset, 0)
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

    static func showsForEnglishGrammarCandidatesAfterTrimming() throws {
        try expectEqual(
            SelectionHotZonePolicy.decision(
                accessibilityTrusted: true,
                selectedText: "\n  The market are unpredictable in short-term.  ",
                frontmostBundleIdentifier: "com.apple.TextEdit",
                ownBundleIdentifier: "com.zhixing.sayflow"
            ),
            .show("The market are unpredictable in short-term.")
        )

        try expectEqual(
            SelectionHotZonePolicy.decision(
                accessibilityTrusted: true,
                selectedText: "This paragraph are awkward.\nIt need a clearer sentence.",
                frontmostBundleIdentifier: "com.apple.TextEdit",
                ownBundleIdentifier: "com.zhixing.sayflow"
            ),
            .show("This paragraph are awkward.\nIt need a clearer sentence.")
        )
    }

    static func showsForChineseIntroFollowedByEnglishSentence() throws {
        let selection = """
        这是一段纯中文说明。

        The market are unpredictable in short-term.
        """

        try expectEqual(
            SelectionHotZonePolicy.decision(
                accessibilityTrusted: true,
                selectedText: selection,
                frontmostBundleIdentifier: "com.apple.TextEdit",
                ownBundleIdentifier: "com.zhixing.sayflow"
            ),
            .show("这是一段纯中文说明。\n\nThe market are unpredictable in short-term.")
        )
    }

    static func showsForInlineChineseIntroFollowedByEnglishSentence() throws {
        let selection = "在持续整理，经验复盘，还有沟通术，还有项目的总结。Continuing summarize experience and how to communicate with AI agent and summarize project."

        try expectEqual(
            SelectionHotZonePolicy.decision(
                accessibilityTrusted: true,
                selectedText: selection,
                frontmostBundleIdentifier: "com.apple.TextEdit",
                ownBundleIdentifier: "com.zhixing.sayflow"
            ),
            .show(selection)
        )
    }

    static func showsForInlineChineseContextFollowedByEnglishPhrase() throws {
        let selection = "带狗下楼洗澡，bring a dog to the 宠物店。"

        try expectEqual(
            SelectionHotZonePolicy.decision(
                accessibilityTrusted: true,
                selectedText: selection,
                frontmostBundleIdentifier: "com.apple.TextEdit",
                ownBundleIdentifier: "com.zhixing.sayflow"
            ),
            .show(selection)
        )
    }

    static func hidesSelectionsThatAreUnsuitableForGrammarCorrection() throws {
        let hiddenSelections = [
            "  中文开头 should not show",
            "https://example.com/article",
            "http://example.com/article",
            "sk-live-token-value",
            "sk_secret_token_value",
            "Bearer abc.def.ghi",
            "ghp_abcdefghijklmnopqrstuvwxyz",
            "xoxb-1234567890-abcdef",
            "1234567890",
            "——---///",
            "writer@example.com",
            "/Users/me/Documents/file.md",
            "~/Documents/file.md",
            "{\"text\":\"hello\"}",
            "<note>hello</note>",
            "let value = response.map { $0.id }",
            "OK"
        ]

        for selection in hiddenSelections {
            try expectEqual(
                SelectionHotZonePolicy.decision(
                    accessibilityTrusted: true,
                    selectedText: selection,
                    frontmostBundleIdentifier: "com.apple.TextEdit",
                    ownBundleIdentifier: "com.zhixing.sayflow"
                ),
                .hide
            )
        }
    }
}

import Foundation

enum WebEditorReplacementPolicyTests {
    static func chromeUsesClipboardPaste() throws {
        try expectEqual(
            WebEditorReplacementPolicy.transport(bundleIdentifier: "com.google.Chrome"),
            .clipboardPaste
        )
    }

    static func safariUsesClipboardPaste() throws {
        try expectEqual(
            WebEditorReplacementPolicy.transport(bundleIdentifier: "com.apple.Safari"),
            .clipboardPaste
        )
    }

    static func nativeApplicationKeepsAccessibilityReplacement() throws {
        try expectEqual(
            WebEditorReplacementPolicy.transport(bundleIdentifier: "com.apple.TextEdit"),
            .accessibility
        )
    }

    static func missingApplicationKeepsAccessibilityReplacement() throws {
        try expectEqual(
            WebEditorReplacementPolicy.transport(bundleIdentifier: nil),
            .accessibility
        )
    }
}

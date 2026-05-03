import Foundation

enum TextCaptureResolverTests {
    static func selectedAccessibilityTextWinsOverClipboard() throws {
        var resolver = TextCaptureResolver()

        let decision = resolver.resolve(
            sampleText: nil,
            accessibilityText: "Selected text",
            clipboardText: "Stale clipboard",
            clipboardChangeCount: 10
        )

        try expectEqual(decision, .captured("Selected text"))
    }

    static func firstAccessibilityMissPromptsInsteadOfUsingStaleClipboard() throws {
        var resolver = TextCaptureResolver()

        let decision = resolver.resolve(
            sampleText: nil,
            accessibilityText: nil,
            clipboardText: "Stale clipboard",
            clipboardChangeCount: 10
        )

        try expectEqual(decision, .needsClipboardCopyPrompt)
    }

    static func clipboardFallbackRequiresClipboardChangeAfterPrompt() throws {
        var resolver = TextCaptureResolver()
        _ = resolver.resolve(
            sampleText: nil,
            accessibilityText: nil,
            clipboardText: "Stale clipboard",
            clipboardChangeCount: 10
        )

        let unchanged = resolver.resolve(
            sampleText: nil,
            accessibilityText: nil,
            clipboardText: "Stale clipboard",
            clipboardChangeCount: 10
        )
        let changed = resolver.resolve(
            sampleText: nil,
            accessibilityText: nil,
            clipboardText: "Copied target",
            clipboardChangeCount: 11
        )

        try expectEqual(unchanged, .needsClipboardCopyPrompt)
        try expectEqual(changed, .captured("Copied target"))
    }

    static func sampleTextBypassesRuntimeCapture() throws {
        var resolver = TextCaptureResolver()

        let decision = resolver.resolve(
            sampleText: "Test run text",
            accessibilityText: nil,
            clipboardText: nil,
            clipboardChangeCount: 0
        )

        try expectEqual(decision, .captured("Test run text"))
    }
}

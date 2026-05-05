import Foundation

enum InsertReplacementFallbackTests {
    static func successfulAccessibilityReplacementNeedsNoClipboardPaste() throws {
        let action = InsertReplacementFallback.action(
            accessibilityReplacementSucceeded: true,
            replacement: "Accessibility selected-text captureI've enabled the accessibility feature to capture selected text."
        )

        try expectEqual(action, .showInsertedFeedback)
    }

    static func failedAccessibilityReplacementFallsBackToClipboardPaste() throws {
        let replacement = "Accessibility selected-text captureI've enabled the accessibility feature to capture selected text."
        let action = InsertReplacementFallback.action(
            accessibilityReplacementSucceeded: false,
            replacement: replacement
        )

        try expectEqual(action, .pasteReplacementThroughClipboard(replacement))
    }

    static func failedInsertionClosesPanelAfterShowingFailure() throws {
        try expectEqual(
            InsertReplacementFallback.finalFailureAction(),
            .showFailureAndClosePanelAfterDelay(1)
        )
    }
}

import Foundation

enum AcceptReplacementFallbackTests {
    static func successfulAccessibilityReplacementNeedsNoClipboardPaste() throws {
        let action = AcceptReplacementFallback.replacementAction(
            accessibilityReplacementSucceeded: true,
            correctedText: "This company is kind of dumb."
        )

        try expectEqual(action, .replacementSucceeded)
    }

    static func failedAccessibilityReplacementFallsBackToClipboardPaste() throws {
        let correctedText = "This company is kind of dumb."
        let action = AcceptReplacementFallback.replacementAction(
            accessibilityReplacementSucceeded: false,
            correctedText: correctedText
        )

        try expectEqual(action, .pasteReplacementThroughClipboard(correctedText))
    }

    static func successfulReplacementClosesPanel() throws {
        let action = AcceptReplacementFallback.completionAction(replacementSucceeded: true)

        try expectEqual(action, .closePanel)
    }

    static func failedReplacementFallsBackToClipboardCopy() throws {
        let action = AcceptReplacementFallback.completionAction(replacementSucceeded: false)

        try expectEqual(action, .copyCorrectedToClipboardAndClosePanelAfterDelay(1))
    }

    static func translationModeAcceptOnlyClosesPanel() throws {
        let action = AcceptReplacementFallback.action(
            mode: .translation,
            replacementSucceeded: false
        )

        try expectEqual(action, .closePanel)
    }
}

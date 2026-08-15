import Foundation

enum AcceptReplacementFallbackTests {
    static func clipboardFallbackClosesPanelBeforeSchedulingPaste() throws {
        var events: [String] = []
        let correctedText = "Like, when I think about it..."

        let outcome = AcceptReplacementFallback.execute(
            action: .pasteReplacementThroughClipboard(correctedText),
            copyToClipboard: { events.append("copy:\($0)") },
            closePanel: { events.append("close") },
            pasteAfterPanelClose: {
                events.append("paste:\($0)")
                return true
            }
        )

        try expectEqual(events, ["copy:\(correctedText)", "close", "paste:\(correctedText)"])
        try expectEqual(outcome, .pasteScheduled)
    }

    static func successfulAttemptSkipsClipboardFallbackSideEffects() throws {
        var events: [String] = []

        let outcome = AcceptReplacementFallback.execute(
            action: .replacementSucceeded,
            copyToClipboard: { events.append("copy:\($0)") },
            closePanel: { events.append("close") },
            pasteAfterPanelClose: {
                events.append("paste:\($0)")
                return true
            }
        )

        try expectEqual(events, [])
        try expectEqual(outcome, .replacementSucceeded)
    }

    static func failedPasteSchedulingIsReported() throws {
        let outcome = AcceptReplacementFallback.execute(
            action: .pasteReplacementThroughClipboard("Corrected"),
            copyToClipboard: { _ in },
            closePanel: {},
            pasteAfterPanelClose: { _ in false }
        )

        try expectEqual(outcome, .pasteSchedulingFailed)
    }

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

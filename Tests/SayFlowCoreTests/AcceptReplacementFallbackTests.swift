import Foundation

enum AcceptReplacementFallbackTests {
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

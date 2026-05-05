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
}

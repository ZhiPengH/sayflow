import Foundation

enum AcceptReplacementFallbackTests {
    static func successfulReplacementNeedsNoClipboardFallback() throws {
        let action = AcceptReplacementFallback.action(replacementSucceeded: true)

        try expectEqual(action, .showReplacedFeedback)
    }

    static func failedReplacementFallsBackToClipboardCopy() throws {
        let action = AcceptReplacementFallback.action(replacementSucceeded: false)

        try expectEqual(action, .copyCorrectedToClipboardAndWarn)
    }
}

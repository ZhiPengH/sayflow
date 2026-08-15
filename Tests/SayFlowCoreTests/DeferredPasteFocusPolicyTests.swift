import Foundation

enum DeferredPasteFocusPolicyTests {
    static func pastesOnlyWhenTargetIsFrontmost() throws {
        let action = DeferredPasteFocusPolicy.action(
            sessionMatches: true,
            targetIsRunning: true,
            clipboardMatches: true,
            selectionMatches: true,
            frontmostPID: 42,
            targetPID: 42,
            retryCount: 0,
            maximumRetryCount: 5
        )

        try expectEqual(action, .paste)
    }

    static func retriesWhileActivationIsPending() throws {
        let action = DeferredPasteFocusPolicy.action(
            sessionMatches: true,
            targetIsRunning: true,
            clipboardMatches: true,
            selectionMatches: false,
            frontmostPID: 7,
            targetPID: 42,
            retryCount: 2,
            maximumRetryCount: 5
        )

        try expectEqual(action, .retryAfterDelay)
    }

    static func cancelsInsteadOfPastingIntoWrongApplication() throws {
        let action = DeferredPasteFocusPolicy.action(
            sessionMatches: true,
            targetIsRunning: true,
            clipboardMatches: true,
            selectionMatches: false,
            frontmostPID: 7,
            targetPID: 42,
            retryCount: 5,
            maximumRetryCount: 5
        )

        try expectEqual(action, .cancel)
    }

    static func cancelsWhenOriginalSelectionCannotBeVerified() throws {
        let action = DeferredPasteFocusPolicy.action(
            sessionMatches: true,
            targetIsRunning: true,
            clipboardMatches: true,
            selectionMatches: false,
            frontmostPID: 42,
            targetPID: 42,
            retryCount: 5,
            maximumRetryCount: 5
        )

        try expectEqual(action, .cancel)
    }

    static func cancelsStaleSession() throws {
        let action = DeferredPasteFocusPolicy.action(
            sessionMatches: false,
            targetIsRunning: true,
            clipboardMatches: true,
            selectionMatches: true,
            frontmostPID: 42,
            targetPID: 42,
            retryCount: 0,
            maximumRetryCount: 5
        )

        try expectEqual(action, .cancel)
    }

    static func cancelsTerminatedTarget() throws {
        let action = DeferredPasteFocusPolicy.action(
            sessionMatches: true,
            targetIsRunning: false,
            clipboardMatches: true,
            selectionMatches: true,
            frontmostPID: 42,
            targetPID: 42,
            retryCount: 0,
            maximumRetryCount: 5
        )

        try expectEqual(action, .cancel)
    }
}

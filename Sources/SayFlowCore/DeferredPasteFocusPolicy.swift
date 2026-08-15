import Foundation

public enum DeferredPasteFocusAction: Equatable {
    case paste
    case retryAfterDelay
    case cancel
}

public enum DeferredPasteFocusPolicy {
    public static func action(
        sessionMatches: Bool,
        targetIsRunning: Bool,
        clipboardMatches: Bool,
        selectionMatches: Bool,
        frontmostPID: Int32?,
        targetPID: Int32,
        retryCount: Int,
        maximumRetryCount: Int
    ) -> DeferredPasteFocusAction {
        guard sessionMatches, targetIsRunning, clipboardMatches else {
            return .cancel
        }
        if frontmostPID == targetPID, selectionMatches {
            return .paste
        }
        return retryCount < maximumRetryCount ? .retryAfterDelay : .cancel
    }
}

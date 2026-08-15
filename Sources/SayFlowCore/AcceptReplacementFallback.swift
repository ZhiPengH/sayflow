import Foundation

public enum AcceptReplacementAttemptAction: Equatable {
    case replacementSucceeded
    case pasteReplacementThroughClipboard(String)
}

public enum AcceptReplacementExecutionOutcome: Equatable {
    case replacementSucceeded
    case pasteScheduled
    case pasteSchedulingFailed
}

public enum AcceptReplacementAction: Equatable {
    case closePanel
    case copyCorrectedToClipboardAndClosePanelAfterDelay(TimeInterval)
}

public enum AcceptReplacementFallback {
    public static let fallbackCloseInterval: TimeInterval = 1

    public static func replacementAction(
        accessibilityReplacementSucceeded: Bool,
        correctedText: String
    ) -> AcceptReplacementAttemptAction {
        accessibilityReplacementSucceeded
            ? .replacementSucceeded
            : .pasteReplacementThroughClipboard(correctedText)
    }

    public static func execute(
        action: AcceptReplacementAttemptAction,
        copyToClipboard: (String) -> Void,
        closePanel: () -> Void,
        pasteAfterPanelClose: (String) -> Bool
    ) -> AcceptReplacementExecutionOutcome {
        switch action {
        case .replacementSucceeded:
            return .replacementSucceeded
        case .pasteReplacementThroughClipboard(let replacement):
            copyToClipboard(replacement)
            closePanel()
            return pasteAfterPanelClose(replacement) ? .pasteScheduled : .pasteSchedulingFailed
        }
    }

    public static func completionAction(replacementSucceeded: Bool) -> AcceptReplacementAction {
        replacementSucceeded ? .closePanel : .copyCorrectedToClipboardAndClosePanelAfterDelay(fallbackCloseInterval)
    }

    public static func action(mode: CorrectionMode, replacementSucceeded: Bool) -> AcceptReplacementAction {
        switch mode {
        case .grammar:
            return completionAction(replacementSucceeded: replacementSucceeded)
        case .translation:
            return .closePanel
        }
    }
}

import Foundation

public enum AcceptReplacementAction: Equatable {
    case closePanel
    case copyCorrectedToClipboardAndClosePanelAfterDelay(TimeInterval)
}

public enum AcceptReplacementFallback {
    public static let fallbackCloseInterval: TimeInterval = 1

    public static func completionAction(replacementSucceeded: Bool) -> AcceptReplacementAction {
        replacementSucceeded ? .closePanel : .copyCorrectedToClipboardAndClosePanelAfterDelay(fallbackCloseInterval)
    }
}

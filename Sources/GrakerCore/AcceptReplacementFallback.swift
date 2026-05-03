import Foundation

public enum AcceptReplacementAction: Equatable {
    case showReplacedFeedback
    case copyCorrectedToClipboardAndWarn
}

public enum AcceptReplacementFallback {
    public static func action(replacementSucceeded: Bool) -> AcceptReplacementAction {
        replacementSucceeded ? .showReplacedFeedback : .copyCorrectedToClipboardAndWarn
    }
}

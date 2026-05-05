import Foundation

public enum InsertReplacementAction: Equatable {
    case showInsertedFeedback
    case pasteReplacementThroughClipboard(String)
    case showFailureAndClosePanelAfterDelay(TimeInterval)
}

public enum InsertReplacementFallback {
    public static func action(
        accessibilityReplacementSucceeded: Bool,
        replacement: String
    ) -> InsertReplacementAction {
        accessibilityReplacementSucceeded
            ? .showInsertedFeedback
            : .pasteReplacementThroughClipboard(replacement)
    }

    public static func finalFailureAction() -> InsertReplacementAction {
        .showFailureAndClosePanelAfterDelay(1)
    }
}

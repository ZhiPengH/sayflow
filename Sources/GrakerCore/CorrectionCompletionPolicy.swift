import Foundation

public enum CorrectionCompletionAction: Equatable {
    case complete(CorrectionSnapshot)
    case malformedJSON(raw: String?)
}

public enum CorrectionCompletionPolicy {
    public static func action(for snapshot: CorrectionSnapshot) -> CorrectionCompletionAction {
        guard let parseError = snapshot.parseError else {
            return .complete(snapshot)
        }
        return .malformedJSON(raw: snapshot.rawResponse.isEmpty ? parseError : snapshot.rawResponse)
    }
}

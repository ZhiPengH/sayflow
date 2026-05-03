import Foundation

enum CorrectionCompletionPolicyTests {
    static func completeSnapshotRoutesToCompletion() throws {
        let snapshot = CorrectionSnapshot(corrected: "She has a plan.", isComplete: true)

        try expectEqual(CorrectionCompletionPolicy.action(for: snapshot), .complete(snapshot))
    }

    static func malformedSnapshotRoutesToRetryErrorWithRawResponse() throws {
        let snapshot = CorrectionSnapshot(
            isComplete: false,
            parseError: "AI returned invalid or incomplete correction JSON.",
            rawResponse: "{\"corrected\":42}"
        )

        try expectEqual(
            CorrectionCompletionPolicy.action(for: snapshot),
            .malformedJSON(raw: "{\"corrected\":42}")
        )
    }

    static func malformedSnapshotFallsBackToParseErrorWhenRawResponseIsEmpty() throws {
        let snapshot = CorrectionSnapshot(
            isComplete: false,
            parseError: "AI returned invalid or incomplete correction JSON.",
            rawResponse: ""
        )

        try expectEqual(
            CorrectionCompletionPolicy.action(for: snapshot),
            .malformedJSON(raw: "AI returned invalid or incomplete correction JSON.")
        )
    }
}

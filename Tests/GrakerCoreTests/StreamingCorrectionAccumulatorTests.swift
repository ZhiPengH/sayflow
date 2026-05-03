import Foundation

enum StreamingCorrectionAccumulatorTests {
    static func publishesFieldsAsSoonAsTheyBecomeComplete() throws {
        var accumulator = StreamingCorrectionAccumulator()

        var snapshot = accumulator.append("{\"corrected\":\"The market is")
        try expectNil(snapshot.corrected)

        snapshot = accumulator.append(" unpredictable in the short term.\",\"changes\":[")
        try expectEqual(snapshot.corrected, "The market is unpredictable in the short term.")
        try expectNil(snapshot.changes)

        snapshot = accumulator.append("{\"old\":\"market are\",\"new\":\"market is\",\"explain\":\"主语是单数\"}],")
        try expectEqual(snapshot.changes, [
            GrammarChange(old: "market are", new: "market is", explain: "主语是单数")
        ])
        try expectNil(snapshot.translationZh)

        snapshot = accumulator.append("\"translation_zh\":\"市场在短期内不可预测。\",")
        try expectEqual(snapshot.translationZh, "市场在短期内不可预测。")

        snapshot = accumulator.append("\"good_to_know\":\"先找主语，再配动词。\"}")
        try expectEqual(snapshot.goodToKnow, "先找主语，再配动词。")
        try expect(snapshot.isComplete)
    }

    static func acceptsMarkdownFencedJSONAndReportsCompleteObject() throws {
        var accumulator = StreamingCorrectionAccumulator()

        let snapshot = accumulator.append("""
        ```json
        {"corrected":"She has a plan.","changes":[{"old":"have","new":"has","explain":"第三人称单数"}],"translation_zh":"她有一个计划。","good_to_know":"第三人称单数要小心。"}
        ```
        """)

        try expectEqual(snapshot.corrected, "She has a plan.")
        try expectEqual(snapshot.changes?.first?.new, "has")
        try expect(snapshot.isComplete)
        try expectNil(snapshot.parseError)
    }

    static func invalidCompletedJSONKeepsRawResponseForDebugging() throws {
        var accumulator = StreamingCorrectionAccumulator()

        let snapshot = accumulator.finish(with: "{\"corrected\": 42}")

        try expect(!snapshot.isComplete)
        try expectNotNil(snapshot.parseError)
        try expectEqual(snapshot.rawResponse, "{\"corrected\": 42}")
    }
}

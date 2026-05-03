import Foundation

enum DiffPillLocatorTests {
    static func locatesChangedSpansInCorrectionOrder() throws {
        let ranges = DiffPillLocator.ranges(
            in: "The market is unpredictable in the short term.",
            changes: [
                GrammarChange(old: "market are", new: "market is", explain: "agreement"),
                GrammarChange(old: "in short-term", new: "in the short term", explain: "phrase")
            ]
        )

        try expectEqual(ranges, [
            DiffPillRange(changeIndex: 0, location: 4, length: 9),
            DiffPillRange(changeIndex: 1, location: 28, length: 17)
        ])
    }

    static func repeatedReplacementTextUsesNextOccurrence() throws {
        let ranges = DiffPillLocator.ranges(
            in: "I am ready and I am focused.",
            changes: [
                GrammarChange(old: "is ready", new: "am ready", explain: "first"),
                GrammarChange(old: "is focused", new: "am focused", explain: "second")
            ]
        )

        try expectEqual(ranges, [
            DiffPillRange(changeIndex: 0, location: 2, length: 8),
            DiffPillRange(changeIndex: 1, location: 17, length: 10)
        ])
    }

    static func skipsMissingOrEmptyReplacementText() throws {
        let ranges = DiffPillLocator.ranges(
            in: "She has a plan.",
            changes: [
                GrammarChange(old: "", new: "", explain: "empty"),
                GrammarChange(old: "have", new: "has", explain: "present")
            ]
        )

        try expectEqual(ranges, [
            DiffPillRange(changeIndex: 1, location: 4, length: 3)
        ])
    }
}

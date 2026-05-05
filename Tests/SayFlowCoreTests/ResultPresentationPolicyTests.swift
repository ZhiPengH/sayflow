import Foundation

enum ResultPresentationPolicyTests {
    static func completedCorrectionAutoCopiesCorrectedText() throws {
        let corrected = "Reviewing my notes this morning really fried my brain, so I ended up sleeping straight through until the afternoon."
        let snapshot = CorrectionSnapshot(
            corrected: corrected,
            changes: [],
            translationZh: "早上的复盘内容让我很烧脑，所以我一觉睡到了下午。",
            isComplete: true
        )

        try expectEqual(ResultPresentationPolicy.autoClipboardText(for: snapshot), corrected)
    }

    static func insertReplacementKeepsOriginalBeforeCorrectedWithoutSeparator() throws {
        let original = "早上的复盘内容有点烧脑，一觉醒来已是下午。"
        let corrected = "Reviewing my notes this morning really fried my brain, so I ended up sleeping straight through until the afternoon."

        try expectEqual(
            ResultPresentationPolicy.insertReplacement(originalText: original, correctedText: corrected),
            "\(original)\(corrected)"
        )
    }
}

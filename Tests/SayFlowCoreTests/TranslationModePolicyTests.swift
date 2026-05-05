import Foundation

enum TranslationModePolicyTests {
    static func singleEnglishWordUsesTranslationMode() throws {
        try expectEqual(CorrectionModePolicy.mode(for: "Accessibility"), .translation)
    }

    static func hyphenatedThreeWordPhraseUsesTranslationMode() throws {
        try expectEqual(CorrectionModePolicy.mode(for: "Accessibility selected-text capture"), .translation)
    }

    static func fourWordsStayInGrammarMode() throws {
        try expectEqual(CorrectionModePolicy.mode(for: "Accessibility selected text capture"), .grammar)
    }

    static func sentenceWithPunctuationStaysInGrammarMode() throws {
        try expectEqual(CorrectionModePolicy.mode(for: "I like accessibility."), .grammar)
    }

    static func translationPresentationForcesFixedModeLabel() throws {
        let snapshot = CorrectionSnapshot(
            corrected: "发音：美/ˌæksɛsəˈbɪlɪti/",
            changes: [
                GrammarChange(old: "Accessibility", new: "Accessibility", explain: "No grammar change.")
            ],
            translationZh: "n.\n可访问性",
            goodToKnow: "Anything else",
            isComplete: true
        )

        let presented = TranslationModePresentation.snapshot(snapshot, mode: .translation)

        try expectEqual(presented.mode, .translation)
        try expectEqual(presented.changes, [])
        try expectEqual(presented.goodToKnow, "🦄翻译模式🌈")
    }

    static func grammarPresentationKeepsOriginalLearningTip() throws {
        let snapshot = CorrectionSnapshot(
            corrected: "I like architecture.",
            changes: [],
            translationZh: "我喜欢建筑。",
            goodToKnow: "Good job.",
            isComplete: true
        )

        let presented = TranslationModePresentation.snapshot(snapshot, mode: .grammar)

        try expectEqual(presented.mode, .grammar)
        try expectEqual(presented.goodToKnow, "Good job.")
    }
}

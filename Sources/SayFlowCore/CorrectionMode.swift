import Foundation

public enum CorrectionMode: String, Codable, Equatable {
    case grammar
    case translation
}

public enum CorrectionModePolicy {
    public static func mode(for selectedText: String) -> CorrectionMode {
        let tokens = selectedText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0.isWhitespace })
        guard (1...3).contains(tokens.count),
              tokens.allSatisfy(isEnglishWordToken) else {
            return .grammar
        }
        return .translation
    }

    private static func isEnglishWordToken(_ token: Substring) -> Bool {
        let pattern = #"^[A-Za-z]+(?:[-'][A-Za-z]+)*$"#
        return token.range(of: pattern, options: .regularExpression) != nil
    }
}

public enum TranslationModePresentation {
    public static let label = "🦄翻译模式🌈"

    public static func snapshot(_ snapshot: CorrectionSnapshot, mode: CorrectionMode) -> CorrectionSnapshot {
        var presented = snapshot
        presented.mode = mode
        guard mode == .translation else {
            return presented
        }
        presented.changes = []
        presented.goodToKnow = label
        return presented
    }
}

import Foundation

public struct StreamingCorrectionAccumulator {
    private var raw = ""

    public init() {}

    public mutating func append(_ fragment: String) -> CorrectionSnapshot {
        raw += fragment
        return makeSnapshot(finished: false)
    }

    public mutating func finish(with response: String? = nil) -> CorrectionSnapshot {
        if let response {
            raw = response
        }
        return makeSnapshot(finished: true)
    }

    private func makeSnapshot(finished: Bool) -> CorrectionSnapshot {
        let sanitized = sanitize(raw)
        if let full = decodeFullCorrection(from: sanitized) {
            return CorrectionSnapshot(
                mode: full.mode,
                corrected: full.corrected,
                changes: full.changes,
                translationZh: full.translationZh,
                goodToKnow: full.goodToKnow,
                isComplete: true,
                parseError: nil,
                rawResponse: raw
            )
        }

        let snapshot = CorrectionSnapshot(
            mode: extractMode(from: sanitized),
            corrected: extractStringField("corrected", from: sanitized),
            changes: extractChanges(from: sanitized),
            translationZh: extractStringField("translation_zh", from: sanitized),
            goodToKnow: extractStringField("good_to_know", from: sanitized),
            isComplete: false,
            parseError: finished ? "AI returned invalid or incomplete correction JSON." : nil,
            rawResponse: raw
        )
        return snapshot
    }

    private func extractMode(from text: String) -> CorrectionMode {
        guard let rawMode = extractStringField("mode", from: text),
              let mode = CorrectionMode(rawValue: rawMode) else {
            return .grammar
        }
        return mode
    }

    private func decodeFullCorrection(from text: String) -> GrammarCorrection? {
        guard let data = text.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(GrammarCorrection.self, from: data)
    }

    private func extractStringField(_ key: String, from text: String) -> String? {
        guard let keyRange = text.range(of: "\"\(key)\"") else {
            return nil
        }
        var index = keyRange.upperBound
        skipWhitespace(in: text, from: &index)
        guard index < text.endIndex, text[index] == ":" else {
            return nil
        }
        index = text.index(after: index)
        skipWhitespace(in: text, from: &index)
        guard index < text.endIndex, text[index] == "\"" else {
            return nil
        }

        let start = index
        index = text.index(after: index)
        var escaped = false
        while index < text.endIndex {
            let character = text[index]
            if escaped {
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else if character == "\"" {
                let literal = String(text[start...index])
                return decodeJSONStringLiteral(literal)
            }
            index = text.index(after: index)
        }
        return nil
    }

    private func extractChanges(from text: String) -> [GrammarChange]? {
        guard let keyRange = text.range(of: "\"changes\"") else {
            return nil
        }
        var index = keyRange.upperBound
        skipWhitespace(in: text, from: &index)
        guard index < text.endIndex, text[index] == ":" else {
            return nil
        }
        index = text.index(after: index)
        skipWhitespace(in: text, from: &index)
        guard index < text.endIndex, text[index] == "[" else {
            return nil
        }
        guard let end = matchingBracket(in: text, from: index, open: "[", close: "]") else {
            return nil
        }
        let arrayText = String(text[index...end])
        guard let data = arrayText.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode([GrammarChange].self, from: data)
    }

    private func sanitize(_ text: String) -> String {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("```") {
            if let firstLineEnd = value.firstIndex(of: "\n") {
                value.removeSubrange(...firstLineEnd)
            }
            value = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if value.hasSuffix("```") {
                value.removeLast(3)
                value = value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return value
    }

    private func decodeJSONStringLiteral(_ literal: String) -> String? {
        guard let data = literal.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(String.self, from: data)
    }

    private func skipWhitespace(in text: String, from index: inout String.Index) {
        while index < text.endIndex, text[index].isWhitespace {
            index = text.index(after: index)
        }
    }

    private func matchingBracket(in text: String, from start: String.Index, open: Character, close: Character) -> String.Index? {
        var index = start
        var depth = 0
        var insideString = false
        var escaped = false

        while index < text.endIndex {
            let character = text[index]
            if insideString {
                if escaped {
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    insideString = false
                }
            } else {
                if character == "\"" {
                    insideString = true
                } else if character == open {
                    depth += 1
                } else if character == close {
                    depth -= 1
                    if depth == 0 {
                        return index
                    }
                }
            }
            index = text.index(after: index)
        }
        return nil
    }
}

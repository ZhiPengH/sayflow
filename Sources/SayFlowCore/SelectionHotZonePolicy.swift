import Foundation

public enum SelectionHotZonePresentation {
    public static let triggerButtonTitle = ""
    public static let triggerIconFileName = "icon_32x32@2x.png"
    public static let triggerIconPointSize = 32
    public static let triggerPanelSideLength = 32
    public static let triggerButtonInset = 0
}

public enum SelectionHotZoneDecision: Equatable {
    case show(String)
    case hide
}

public enum SelectionHotZonePolicy {
    public static func decision(
        accessibilityTrusted: Bool,
        selectedText: String?,
        frontmostBundleIdentifier: String?,
        ownBundleIdentifier: String
    ) -> SelectionHotZoneDecision {
        guard accessibilityTrusted else {
            return .hide
        }
        guard frontmostBundleIdentifier != ownBundleIdentifier else {
            return .hide
        }
        guard let text = selectedText?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            return .hide
        }
        guard SelectionHotZoneContentPolicy.isSuitableGrammarCandidate(text) else {
            return .hide
        }
        return .show(text)
    }
}

private enum SelectionHotZoneContentPolicy {
    private static let minimumTextLength = 6

    static func isSuitableGrammarCandidate(_ text: String) -> Bool {
        guard text.count >= minimumTextLength else {
            return false
        }
        if isChineseIntroFollowedByEnglishSentence(text) {
            return true
        }
        guard let firstScalar = firstContentScalar(in: text), !isChinese(firstScalar) else {
            return false
        }
        guard containsASCIILetter(text) else {
            return false
        }
        if looksLikeURL(text) || looksLikeSecret(text) || looksLikeEmailAddress(text) {
            return false
        }
        if looksLikeFilePath(text) || looksLikeStructuredData(text) || looksLikeCodeSnippet(text) {
            return false
        }
        return true
    }

    private static func firstContentScalar(in text: String) -> Unicode.Scalar? {
        let ignored = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"'“”‘’([{"))
        return text.unicodeScalars.first { !ignored.contains($0) }
    }

    private static func isChinese(_ scalar: Unicode.Scalar) -> Bool {
        let value = scalar.value
        return (0x3400...0x4DBF).contains(value)
            || (0x4E00...0x9FFF).contains(value)
            || (0xF900...0xFAFF).contains(value)
    }

    private static func containsASCIILetter(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (65...90).contains(Int(scalar.value)) || (97...122).contains(Int(scalar.value))
        }
    }

    private static func isChineseIntroFollowedByEnglishSentence(_ text: String) -> Bool {
        if isNewlineSeparatedChineseIntroFollowedByEnglishSentence(text) {
            return true
        }
        return isInlineChineseIntroFollowedByEnglishSentence(text)
    }

    private static func isNewlineSeparatedChineseIntroFollowedByEnglishSentence(_ text: String) -> Bool {
        let paragraphs = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard paragraphs.count >= 2,
              isPureChineseParagraph(paragraphs[0]) else {
            return false
        }
        return paragraphs.dropFirst().contains { isEnglishGrammarCandidateSegment($0) }
    }

    private static func isInlineChineseIntroFollowedByEnglishSentence(_ text: String) -> Bool {
        guard let englishStart = text.unicodeScalars.firstIndex(where: { isASCIILetter($0) }) else {
            return false
        }
        let intro = String(text.unicodeScalars[..<englishStart]).trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = String(text.unicodeScalars[englishStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard isPureChineseParagraph(intro),
              endsWithSentenceTerminator(intro) else {
            return false
        }
        return isEnglishGrammarCandidateSegment(candidate)
    }

    private static func isEnglishGrammarCandidateSegment(_ text: String) -> Bool {
        guard let firstScalar = firstContentScalar(in: text),
              !isChinese(firstScalar),
              containsASCIILetter(text) else {
            return false
        }
        return !looksLikeURL(text)
            && !looksLikeSecret(text)
            && !looksLikeEmailAddress(text)
            && !looksLikeFilePath(text)
            && !looksLikeStructuredData(text)
            && !looksLikeCodeSnippet(text)
    }

    private static func endsWithSentenceTerminator(_ text: String) -> Bool {
        let ignored = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"'”’》）」）]"))
        guard let finalScalar = text.unicodeScalars.reversed().first(where: { !ignored.contains($0) }) else {
            return false
        }
        return CharacterSet(charactersIn: "。！？!?").contains(finalScalar)
    }

    private static func isPureChineseParagraph(_ text: String) -> Bool {
        var hasChinese = false
        for scalar in text.unicodeScalars {
            if isChinese(scalar) {
                hasChinese = true
            } else if isASCIILetter(scalar) || CharacterSet.decimalDigits.contains(scalar) {
                return false
            }
        }
        return hasChinese
    }

    private static func isASCIILetter(_ scalar: Unicode.Scalar) -> Bool {
        (65...90).contains(Int(scalar.value)) || (97...122).contains(Int(scalar.value))
    }

    private static func looksLikeURL(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        return lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://")
    }

    private static func looksLikeSecret(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        let secretPrefixes = [
            "sk-", "sk_", "bearer ", "ghp_", "gho_", "github_pat_",
            "xoxb-", "xoxp-", "xoxa-", "xoxr-"
        ]
        if secretPrefixes.contains(where: { lowercased.hasPrefix($0) }) {
            return true
        }
        if lowercased.hasPrefix("sk"), text.count >= 12, !containsWhitespace(text) {
            return true
        }
        let secretMarkers = [
            "api_key=", "api-key=", "apikey=", "access_token=", "refresh_token=",
            "token=", "secret=", "authorization: bearer"
        ]
        return secretMarkers.contains(where: { lowercased.contains($0) })
    }

    private static func looksLikeEmailAddress(_ text: String) -> Bool {
        guard !containsWhitespace(text),
              let atIndex = text.firstIndex(of: "@"),
              atIndex != text.startIndex,
              atIndex != text.index(before: text.endIndex) else {
            return false
        }
        return text[text.index(after: atIndex)...].contains(".")
    }

    private static func looksLikeFilePath(_ text: String) -> Bool {
        if text.hasPrefix("/") || text.hasPrefix("~/") || text.hasPrefix("./") || text.hasPrefix("../") {
            return true
        }
        if text.count >= 3 {
            let characters = Array(text.prefix(3))
            if characters[1] == ":", characters[2] == "\\" || characters[2] == "/" {
                return true
            }
        }
        if !containsWhitespace(text), text.contains("/"), text.contains(".") {
            return true
        }
        return false
    }

    private static func looksLikeStructuredData(_ text: String) -> Bool {
        if (text.hasPrefix("{") && text.hasSuffix("}")) || (text.hasPrefix("[") && text.hasSuffix("]")) {
            return true
        }
        if text.hasPrefix("<"), text.contains(">"), text.contains("</") || text.hasSuffix("/>") {
            return true
        }
        return false
    }

    private static func looksLikeCodeSnippet(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        let codePrefixes = [
            "let ", "var ", "func ", "function ", "const ", "import ", "export ",
            "class ", "struct ", "enum ", "public ", "private ", "#include", "def ",
            "if (", "for (", "while ("
        ]
        if codePrefixes.contains(where: { lowercased.hasPrefix($0) }) {
            return true
        }
        if text.contains("```") || text.contains("=>") {
            return true
        }
        if text.contains("{"), text.contains("}"), text.contains(";") || lowercased.contains("return ") {
            return true
        }
        return false
    }

    private static func containsWhitespace(_ text: String) -> Bool {
        text.unicodeScalars.contains { CharacterSet.whitespacesAndNewlines.contains($0) }
    }
}

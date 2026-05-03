import Foundation

public enum HotKeyParser {
    private static let optionModifierFlags: UInt32 = 1 << 11
    private static let keyCodes: [Character: UInt32] = [
        "A": 0, "S": 1, "D": 2, "F": 3, "H": 4, "G": 5, "Z": 6, "X": 7, "C": 8, "V": 9,
        "B": 11, "Q": 12, "W": 13, "E": 14, "R": 15, "Y": 16, "T": 17, "O": 31, "U": 32,
        "I": 34, "P": 35, "L": 37, "J": 38, "K": 40, "N": 45, "M": 46
    ]

    public static func parse(_ text: String) -> HotKeyConfiguration? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else {
            return nil
        }

        let letter: Character?
        if trimmed.hasPrefix("⌥") {
            letter = symbolShortcutLetter(from: trimmed)
        } else {
            letter = wordShortcutLetter(from: trimmed)
        }

        guard let letter, let keyCode = keyCodes[letter] else {
            return nil
        }
        return HotKeyConfiguration(displayText: "⌥\(letter)", keyCode: keyCode, modifierFlags: optionModifierFlags)
    }

    private static func symbolShortcutLetter(from text: String) -> Character? {
        var remainder = String(text.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        if remainder.hasPrefix("+") {
            remainder = String(remainder.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard remainder.count == 1 else {
            return nil
        }
        return remainder.first
    }

    private static func wordShortcutLetter(from text: String) -> Character? {
        let parts = text
            .replacingOccurrences(of: "+", with: " ")
            .split(whereSeparator: { $0 == " " || $0 == "\t" })
            .map(String.init)
        guard parts.count == 2,
              parts[0] == "OPTION" || parts[0] == "ALT",
              parts[1].count == 1 else {
            return nil
        }
        return parts[1].first
    }
}

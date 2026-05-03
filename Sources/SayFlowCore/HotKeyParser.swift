import Foundation

public enum HotKeyParser {
    private static let optionModifierFlags: UInt32 = 1 << 11
    private static let controlCommandModifierFlags: UInt32 = (1 << 12) | (1 << 8)
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

        let parsed: (letter: Character, modifierFlags: UInt32)?
        if trimmed.hasPrefix("⌥") || trimmed.hasPrefix("⌃") || trimmed.hasPrefix("⌘") {
            parsed = symbolShortcut(from: trimmed)
        } else {
            parsed = wordShortcut(from: trimmed)
        }

        guard let parsed, let keyCode = keyCodes[parsed.letter] else {
            return nil
        }
        return HotKeyConfiguration(
            displayText: displayText(letter: parsed.letter, modifierFlags: parsed.modifierFlags),
            keyCode: keyCode,
            modifierFlags: parsed.modifierFlags
        )
    }

    private static func symbolShortcut(from text: String) -> (Character, UInt32)? {
        let compact = text.replacingOccurrences(of: "+", with: "").filter { !$0.isWhitespace }
        guard let letter = compact.last, keyCodes[letter] != nil else {
            return nil
        }
        let modifierSymbols = compact.dropLast()
        let modifiers = Set(modifierSymbols)
        guard modifiers.count == modifierSymbols.count else {
            return nil
        }
        if modifiers == ["⌥"] {
            return (letter, optionModifierFlags)
        }
        if modifiers == ["⌃", "⌘"] {
            return (letter, controlCommandModifierFlags)
        }
        return nil
    }

    private static func wordShortcut(from text: String) -> (Character, UInt32)? {
        let parts = text
            .replacingOccurrences(of: "+", with: " ")
            .split(whereSeparator: { $0 == " " || $0 == "\t" })
            .map(String.init)
        guard let letterText = parts.last, letterText.count == 1, let letter = letterText.first else {
            return nil
        }
        let modifiers = Set(parts.dropLast())
        if modifiers == ["OPTION"] || modifiers == ["ALT"] {
            return (letter, optionModifierFlags)
        }
        let hasControl = modifiers.contains("CONTROL") || modifiers.contains("CTRL") || modifiers.contains("CTL")
        let hasCommand = modifiers.contains("COMMAND") || modifiers.contains("CMD")
        if modifiers.count == 2, hasControl, hasCommand {
            return (letter, controlCommandModifierFlags)
        }
        return nil
    }

    private static func displayText(letter: Character, modifierFlags: UInt32) -> String {
        if modifierFlags == optionModifierFlags {
            return "⌥\(letter)"
        }
        return "⌃⌘\(letter)"
    }
}

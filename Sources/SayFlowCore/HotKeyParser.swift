import Foundation

public enum HotKeyParser {
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

        guard let parsed, let keyCode = HotKeyKeyboardMap.keyCodes[parsed.letter] else {
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
        guard let letter = compact.last, HotKeyKeyboardMap.keyCodes[letter] != nil else {
            return nil
        }
        let modifierSymbols = compact.dropLast()
        var modifierFlags: UInt32 = 0
        var seenFlags: Set<UInt32> = []
        for symbol in modifierSymbols {
            guard let flag = HotKeyModifierFlags.flag(forSymbol: symbol), !seenFlags.contains(flag) else {
                return nil
            }
            modifierFlags |= flag
            seenFlags.insert(flag)
        }
        guard HotKeyModifierFlags.isSupportedShortcutCombination(modifierFlags) else {
            return nil
        }
        return (letter, modifierFlags)
    }

    private static func wordShortcut(from text: String) -> (Character, UInt32)? {
        let parts = text
            .replacingOccurrences(of: "+", with: " ")
            .split(whereSeparator: { $0 == " " || $0 == "\t" })
            .map(String.init)
        guard let letterText = parts.last, letterText.count == 1, let letter = letterText.first else {
            return nil
        }
        var modifierFlags: UInt32 = 0
        var seenFlags: Set<UInt32> = []
        for modifier in parts.dropLast() {
            guard let flag = HotKeyModifierFlags.flag(forWord: modifier), !seenFlags.contains(flag) else {
                return nil
            }
            modifierFlags |= flag
            seenFlags.insert(flag)
        }
        guard HotKeyModifierFlags.isSupportedShortcutCombination(modifierFlags) else {
            return nil
        }
        return (letter, modifierFlags)
    }

    private static func displayText(letter: Character, modifierFlags: UInt32) -> String {
        HotKeyModifierFlags.displayText(for: modifierFlags) + String(letter)
    }
}

public struct HotKeyMenuShortcut: Equatable {
    public let keyEquivalent: String
    public let modifierFlags: UInt32

    public init(keyEquivalent: String, modifierFlags: UInt32) {
        self.keyEquivalent = keyEquivalent
        self.modifierFlags = modifierFlags
    }
}

public enum HotKeyMenuShortcutPresentation {
    public static func shortcut(for configuration: HotKeyConfiguration) -> HotKeyMenuShortcut {
        let keyEquivalent = HotKeyKeyboardMap.keyEquivalent(for: configuration.keyCode)
            ?? configuration.displayText.last.map { String($0).lowercased() }
            ?? ""
        return HotKeyMenuShortcut(keyEquivalent: keyEquivalent, modifierFlags: configuration.modifierFlags)
    }
}

private enum HotKeyKeyboardMap {
    static let keyCodes: [Character: UInt32] = [
        "A": 0, "S": 1, "D": 2, "F": 3, "H": 4, "G": 5, "Z": 6, "X": 7, "C": 8, "V": 9,
        "B": 11, "Q": 12, "W": 13, "E": 14, "R": 15, "Y": 16, "T": 17, "O": 31, "U": 32,
        "I": 34, "P": 35, "L": 37, "J": 38, "K": 40, "N": 45, "M": 46
    ]

    private static let keyEquivalentsByCode = Dictionary(uniqueKeysWithValues: keyCodes.map { entry in
        (entry.value, String(entry.key).lowercased())
    })

    static func keyEquivalent(for keyCode: UInt32) -> String? {
        keyEquivalentsByCode[keyCode]
    }
}

private enum HotKeyModifierFlags {
    static let command: UInt32 = 1 << 8
    static let shift: UInt32 = 1 << 9
    static let option: UInt32 = 1 << 11
    static let control: UInt32 = 1 << 12

    static func flag(forSymbol symbol: Character) -> UInt32? {
        switch symbol {
        case "⌘":
            return command
        case "⇧":
            return shift
        case "⌥":
            return option
        case "⌃":
            return control
        default:
            return nil
        }
    }

    static func flag(forWord word: String) -> UInt32? {
        switch word {
        case "COMMAND", "CMD":
            return command
        case "SHIFT":
            return shift
        case "OPTION", "ALT":
            return option
        case "CONTROL", "CTRL", "CTL":
            return control
        default:
            return nil
        }
    }

    static func isSupportedShortcutCombination(_ modifierFlags: UInt32) -> Bool {
        let nonShiftModifiers = modifierFlags & ~shift
        guard nonShiftModifiers != 0 else {
            return false
        }
        if modifierFlags == command || modifierFlags == control {
            return false
        }
        return true
    }

    static func displayText(for modifierFlags: UInt32) -> String {
        var text = ""
        if modifierFlags & control != 0 {
            text += "⌃"
        }
        if modifierFlags & option != 0 {
            text += "⌥"
        }
        if modifierFlags & shift != 0 {
            text += "⇧"
        }
        if modifierFlags & command != 0 {
            text += "⌘"
        }
        return text
    }
}

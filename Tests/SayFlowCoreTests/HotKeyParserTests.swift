import Foundation

enum HotKeyParserTests {
    static func parsesSymbolAndWordBasedControlCommandShortcuts() throws {
        try expectEqual(HotKeyParser.parse("⌃⌘S"), .defaultControlCommandS)
        try expectEqual(HotKeyParser.parse("Control+Command+S"), .defaultControlCommandS)
        try expectEqual(HotKeyParser.parse("Ctrl+Cmd+S"), .defaultControlCommandS)
        try expectEqual(HotKeyParser.parse("ctl+cmd+s"), .defaultControlCommandS)
    }

    static func stillParsesCustomOptionShortcutsForExistingUsers() throws {
        try expectEqual(
            HotKeyParser.parse("Alt+H"),
            HotKeyConfiguration(displayText: "⌥H", keyCode: 4, modifierFlags: 1 << 11)
        )
    }

    static func parsesCustomModifierLetterShortcuts() throws {
        try expectEqual(
            HotKeyParser.parse("Ctrl+Option+H"),
            HotKeyConfiguration(displayText: "⌃⌥H", keyCode: 4, modifierFlags: (1 << 12) | (1 << 11))
        )
        try expectEqual(
            HotKeyParser.parse("⌥⌃H"),
            HotKeyConfiguration(displayText: "⌃⌥H", keyCode: 4, modifierFlags: (1 << 12) | (1 << 11))
        )
        try expectEqual(
            HotKeyParser.parse("Command+Shift+H"),
            HotKeyConfiguration(displayText: "⇧⌘H", keyCode: 4, modifierFlags: (1 << 9) | (1 << 8))
        )
    }

    static func formatsConfiguredShortcutForMenuPresentation() throws {
        try expectEqual(
            HotKeyMenuShortcutPresentation.shortcut(for: .defaultControlCommandS),
            HotKeyMenuShortcut(keyEquivalent: "s", modifierFlags: (1 << 12) | (1 << 8))
        )
        try expectEqual(
            HotKeyMenuShortcutPresentation.shortcut(
                for: HotKeyConfiguration(displayText: "⌃⌥H", keyCode: 4, modifierFlags: (1 << 12) | (1 << 11))
            ),
            HotKeyMenuShortcut(keyEquivalent: "h", modifierFlags: (1 << 12) | (1 << 11))
        )
    }

    static func rejectsUnsupportedShortcutForms() throws {
        try expectNil(HotKeyParser.parse("G"))
        try expectNil(HotKeyParser.parse("Command+G"))
        try expectNil(HotKeyParser.parse("Control+S"))
        try expectNil(HotKeyParser.parse("Option+1"))
    }
}

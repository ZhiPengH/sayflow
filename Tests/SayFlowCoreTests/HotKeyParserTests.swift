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

    static func rejectsUnsupportedShortcutForms() throws {
        try expectNil(HotKeyParser.parse("G"))
        try expectNil(HotKeyParser.parse("Command+G"))
        try expectNil(HotKeyParser.parse("Control+S"))
        try expectNil(HotKeyParser.parse("Option+1"))
    }
}

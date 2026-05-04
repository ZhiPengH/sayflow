import Foundation

enum MenuBarIconPresentationTests {
    static func capsOversizedMenuBarIconToStatusBarCanvas() throws {
        try expectEqual(MenuBarIconPresentation.resourceFileName, "MenuBarIcon.pdf")
        try expectEqual(MenuBarIconPresentation.normalizedPointSize, 25)
        try expectEqual(MenuBarIconPresentation.displayedPointSize(forSourcePointSize: 33), 25)
        try expectEqual(MenuBarIconPresentation.displayedPointSize(forSourcePointSize: 16), 16)
    }
}

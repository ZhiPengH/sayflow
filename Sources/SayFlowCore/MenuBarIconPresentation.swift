import Foundation

public enum MenuBarIconPresentation {
    public static let resourceFileName = "MenuBarIcon.pdf"
    public static let normalizedPointSize = 25

    public static func displayedPointSize(forSourcePointSize sourcePointSize: Int) -> Int {
        min(sourcePointSize, normalizedPointSize)
    }
}

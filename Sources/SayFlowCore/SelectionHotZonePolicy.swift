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
        return .show(text)
    }
}

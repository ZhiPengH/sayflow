import Foundation

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

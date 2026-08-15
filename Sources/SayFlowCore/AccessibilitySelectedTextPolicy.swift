import Foundation

public enum AccessibilitySelectedTextPolicy {
    public static func resolve(directText: String?, markerText: String?) -> String? {
        if let direct = normalized(directText) {
            return direct
        }
        return normalized(markerText)
    }

    private static func normalized(_ text: String?) -> String? {
        guard let text else {
            return nil
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

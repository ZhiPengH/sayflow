import Foundation

public enum GrammarTriggerPreflight {
    public static func requiresAccessibilityPermission(sampleText: String?) -> Bool {
        guard let sampleText,
              !sampleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return true
        }
        return false
    }
}

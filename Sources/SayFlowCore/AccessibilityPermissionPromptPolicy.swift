import Foundation

public enum AccessibilityPermissionPromptPolicy {
    public enum Context {
        case grammarTrigger
    }

    public static func shouldRequestSystemPrompt(for context: Context) -> Bool {
        switch context {
        case .grammarTrigger:
            return false
        }
    }
}

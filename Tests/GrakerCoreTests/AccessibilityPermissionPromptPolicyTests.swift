import Foundation

enum AccessibilityPermissionPromptPolicyTests {
    static func grammarTriggerUsesSilentPermissionCheck() throws {
        try expectEqual(
            AccessibilityPermissionPromptPolicy.shouldRequestSystemPrompt(for: .grammarTrigger),
            false
        )
    }
}

import Foundation

enum GrammarTriggerPreflightTests {
    static func promptTestRunDoesNotRequireAccessibilityPermission() throws {
        try expectEqual(
            GrammarTriggerPreflight.requiresAccessibilityPermission(sampleText: "The market are unpredictable in short-term."),
            false
        )
    }

    static func runtimeCaptureRequiresAccessibilityPermission() throws {
        try expectEqual(GrammarTriggerPreflight.requiresAccessibilityPermission(sampleText: nil), true)
        try expectEqual(GrammarTriggerPreflight.requiresAccessibilityPermission(sampleText: "   "), true)
    }
}

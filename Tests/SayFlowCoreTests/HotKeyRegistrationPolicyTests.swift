import Foundation

enum HotKeyRegistrationPolicyTests {
    static func succeedsOnlyWhenHandlerAndShortcutRegister() throws {
        try expectEqual(
            HotKeyRegistrationPolicy.evaluate(handlerStatus: 0, shortcutStatus: 0),
            .registered
        )
        try expectEqual(
            HotKeyRegistrationPolicy.evaluate(handlerStatus: -1, shortcutStatus: 0),
            .failed(stage: .eventHandler, status: -1)
        )
        try expectEqual(
            HotKeyRegistrationPolicy.evaluate(handlerStatus: 0, shortcutStatus: -9878),
            .failed(stage: .shortcut, status: -9878)
        )
    }
}

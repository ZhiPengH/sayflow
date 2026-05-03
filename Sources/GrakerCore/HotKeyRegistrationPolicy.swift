import Foundation

public enum HotKeyRegistrationStage: Equatable {
    case eventHandler
    case shortcut
}

public enum HotKeyRegistrationResult: Equatable {
    case registered
    case failed(stage: HotKeyRegistrationStage, status: Int32)
}

public enum HotKeyRegistrationPolicy {
    public static func evaluate(handlerStatus: Int32, shortcutStatus: Int32) -> HotKeyRegistrationResult {
        guard handlerStatus == 0 else {
            return .failed(stage: .eventHandler, status: handlerStatus)
        }
        guard shortcutStatus == 0 else {
            return .failed(stage: .shortcut, status: shortcutStatus)
        }
        return .registered
    }
}

import Foundation

public enum ClipboardShortcutCaptureAction: Equatable {
    case tryCopyShortcut
    case showNoSelectedTextPrompt
}

public enum ClipboardShortcutCapturePolicy {
    public static func action(
        sampleText: String?,
        requiresAccessibility: Bool,
        captureDecision: TextCaptureDecision
    ) -> ClipboardShortcutCaptureAction {
        guard sampleText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false,
              requiresAccessibility,
              captureDecision == .needsClipboardCopyPrompt else {
            return .showNoSelectedTextPrompt
        }
        return .tryCopyShortcut
    }
}

public enum SelectionHotZoneClipboardFallbackPolicy {
    private static let minimumDragDistance = 8.0
    private static let supportedBundleIdentifiers: Set<String> = [
        "com.tencent.xinwechat"
    ]

    public static func action(
        accessibilityTrusted: Bool,
        selectedText: String?,
        frontmostBundleIdentifier: String?,
        ownBundleIdentifier: String,
        mouseDragDistance: Double?
    ) -> ClipboardShortcutCaptureAction {
        guard accessibilityTrusted else {
            return .showNoSelectedTextPrompt
        }
        guard let frontmostBundleIdentifier else {
            return .showNoSelectedTextPrompt
        }
        guard frontmostBundleIdentifier.lowercased() != ownBundleIdentifier.lowercased() else {
            return .showNoSelectedTextPrompt
        }
        if let text = selectedText?.trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            return .showNoSelectedTextPrompt
        }
        guard supportedBundleIdentifiers.contains(frontmostBundleIdentifier.lowercased()) else {
            return .showNoSelectedTextPrompt
        }
        guard let mouseDragDistance,
              mouseDragDistance >= minimumDragDistance else {
            return .showNoSelectedTextPrompt
        }
        return .tryCopyShortcut
    }
}

import Foundation

public enum TextCaptureDecision: Equatable {
    case captured(String)
    case needsClipboardCopyPrompt
}

public struct TextCaptureResolver {
    private var promptedClipboardChangeCount: Int?

    public init() {}

    public mutating func resolve(
        sampleText: String?,
        accessibilityText: String?,
        clipboardText: String?,
        clipboardChangeCount: Int
    ) -> TextCaptureDecision {
        if let text = normalized(sampleText), !text.isEmpty {
            promptedClipboardChangeCount = nil
            return .captured(text)
        }
        if let text = normalized(accessibilityText), !text.isEmpty {
            promptedClipboardChangeCount = nil
            return .captured(text)
        }
        if let promptedClipboardChangeCount,
           clipboardChangeCount != promptedClipboardChangeCount,
           let text = normalized(clipboardText),
           !text.isEmpty {
            self.promptedClipboardChangeCount = nil
            return .captured(text)
        }

        promptedClipboardChangeCount = clipboardChangeCount
        return .needsClipboardCopyPrompt
    }

    private func normalized(_ text: String?) -> String? {
        text?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

import Foundation

public enum ResultPresentationPolicy {
    public static func autoClipboardText(for snapshot: CorrectionSnapshot) -> String? {
        guard snapshot.isComplete,
              let corrected = snapshot.corrected,
              !corrected.isEmpty else {
            return nil
        }
        return corrected
    }

    public static func insertReplacement(originalText: String, correctedText: String) -> String {
        "\(originalText)\(correctedText)"
    }
}

import Foundation

public enum WebEditorReplacementTransport: Equatable {
    case accessibility
    case clipboardPaste
}

public enum WebEditorReplacementPolicy {
    private static let browserBundleIdentifiers: Set<String> = [
        "com.apple.safari",
        "com.apple.safaritechnologypreview",
        "com.brave.browser",
        "com.google.chrome",
        "com.google.chrome.beta",
        "com.google.chrome.canary",
        "com.microsoft.edgemac",
        "com.operasoftware.opera",
        "com.vivaldi.vivaldi",
        "company.thebrowser.browser",
        "org.mozilla.firefox"
    ]

    public static func transport(bundleIdentifier: String?) -> WebEditorReplacementTransport {
        guard let bundleIdentifier else {
            return .accessibility
        }
        return browserBundleIdentifiers.contains(bundleIdentifier.lowercased())
            ? .clipboardPaste
            : .accessibility
    }
}

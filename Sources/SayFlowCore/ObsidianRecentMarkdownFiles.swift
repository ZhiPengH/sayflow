import Foundation

public enum ObsidianRecentMarkdownFiles {
    public static let limit = 5

    public static func adding(_ rawPath: String, to existing: [String]) -> [String] {
        switch ObsidianTargetPathValidator.validate(rawPath) {
        case .valid(let url):
            let path = url.path
            let withoutDuplicate = existing.filter { $0 != path }
            return Array(([path] + withoutDuplicate).prefix(limit))
        case .invalid:
            return Array(existing.prefix(limit))
        }
    }

    public static func displayTitle(for path: String) -> String {
        let components = URL(fileURLWithPath: path).pathComponents.filter { $0 != "/" }
        return components.suffix(3).joined(separator: "/")
    }
}

import Foundation

public enum UpdateAvailability: Equatable {
    case upToDate
    case available(version: String, url: URL?)
}

public enum GitHubReleaseUpdateEvaluator {
    public static func evaluate(latestReleaseJSON data: Data, currentVersion: String) throws -> UpdateAvailability {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String else {
            return .upToDate
        }
        if (json["draft"] as? Bool) == true || (json["prerelease"] as? Bool) == true {
            return .upToDate
        }

        let latest = SemanticVersion(tag)
        let current = SemanticVersion(currentVersion)
        guard latest > current else {
            return .upToDate
        }

        let version = latest.displayText
        let releaseURL = (json["html_url"] as? String).flatMap(URL.init(string:))
        return .available(version: version, url: releaseURL)
    }
}

private struct SemanticVersion: Comparable {
    let parts: [Int]
    let displayText: String

    init(_ rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutPrefix = trimmed.lowercased().hasPrefix("v") ? String(trimmed.dropFirst()) : trimmed
        let numericPrefix = withoutPrefix.prefix { character in
            character.isNumber || character == "."
        }
        let parsedParts = numericPrefix
            .split(separator: ".")
            .map { Int($0) ?? 0 }
        self.parts = parsedParts.isEmpty ? [0] : parsedParts
        self.displayText = String(numericPrefix).isEmpty ? withoutPrefix : String(numericPrefix)
    }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        let count = max(lhs.parts.count, rhs.parts.count)
        for index in 0..<count {
            let left = index < lhs.parts.count ? lhs.parts[index] : 0
            let right = index < rhs.parts.count ? rhs.parts[index] : 0
            if left != right {
                return left < right
            }
        }
        return false
    }
}

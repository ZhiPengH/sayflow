import Foundation

enum UpdateCheckerTests {
    static func detectsNewerGitHubRelease() throws {
        let json = """
        {
          "tag_name": "v1.0.1",
          "html_url": "https://github.com/ZhiPengH/sayflow-release/releases/tag/v1.0.1",
          "draft": false,
          "prerelease": false
        }
        """.data(using: .utf8)!

        let availability = try GitHubReleaseUpdateEvaluator.evaluate(latestReleaseJSON: json, currentVersion: "1.0.0")

        try expectEqual(
            availability,
            .available(
                version: "1.0.1",
                url: URL(string: "https://github.com/ZhiPengH/sayflow-release/releases/tag/v1.0.1")
            )
        )
    }

    static func treatsSameOlderDraftAndPrereleaseAsUpToDate() throws {
        let same = #"{"tag_name":"v1.0.0","draft":false,"prerelease":false}"#.data(using: .utf8)!
        let older = #"{"tag_name":"v0.9.9","draft":false,"prerelease":false}"#.data(using: .utf8)!
        let draft = #"{"tag_name":"v1.0.1","draft":true,"prerelease":false}"#.data(using: .utf8)!
        let prerelease = #"{"tag_name":"v1.0.1-beta.1","draft":false,"prerelease":true}"#.data(using: .utf8)!

        try expectEqual(try GitHubReleaseUpdateEvaluator.evaluate(latestReleaseJSON: same, currentVersion: "1.0.0"), .upToDate)
        try expectEqual(try GitHubReleaseUpdateEvaluator.evaluate(latestReleaseJSON: older, currentVersion: "1.0.0"), .upToDate)
        try expectEqual(try GitHubReleaseUpdateEvaluator.evaluate(latestReleaseJSON: draft, currentVersion: "1.0.0"), .upToDate)
        try expectEqual(try GitHubReleaseUpdateEvaluator.evaluate(latestReleaseJSON: prerelease, currentVersion: "1.0.0"), .upToDate)
    }
}

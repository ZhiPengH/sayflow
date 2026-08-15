import Foundation

enum ReleaseDistributionTests {
    static func pointsToCurrentPublicRepository() throws {
        try expectEqual(ReleaseDistribution.repositorySlug, "ZhiPengH/sayflow")
        try expectEqual(
            ReleaseDistribution.releasesPageURL.absoluteString,
            "https://github.com/ZhiPengH/sayflow/releases"
        )
        try expectEqual(
            ReleaseDistribution.latestStableReleaseAPIURL.absoluteString,
            "https://api.github.com/repos/ZhiPengH/sayflow/releases/latest"
        )
    }
}

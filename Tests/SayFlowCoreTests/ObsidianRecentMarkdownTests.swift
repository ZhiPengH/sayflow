import Foundation

enum ObsidianRecentMarkdownTests {
    static func keepsFiveMostRecentUniqueMarkdownPaths() throws {
        let existing = [
            "/vault/A.md",
            "/vault/B.md",
            "/vault/C.md",
            "/vault/D.md",
            "/vault/E.md"
        ]

        try expectEqual(
            ObsidianRecentMarkdownFiles.adding("/vault/C.md", to: existing),
            ["/vault/C.md", "/vault/A.md", "/vault/B.md", "/vault/D.md", "/vault/E.md"]
        )

        try expectEqual(
            ObsidianRecentMarkdownFiles.adding("/vault/F.md", to: existing),
            ["/vault/F.md", "/vault/A.md", "/vault/B.md", "/vault/C.md", "/vault/D.md"]
        )

        try expectEqual(
            ObsidianRecentMarkdownFiles.adding("/vault/not-markdown.txt", to: existing),
            existing
        )
    }

    static func displaysLastThreePathComponentsWithoutAbsolutePrefix() throws {
        try expectEqual(
            ObsidianRecentMarkdownFiles.displayTitle(for: "/Users/zhipeng/ZhiPengLife/Notes/SayFlow-Inbox.md"),
            "ZhiPengLife/Notes/SayFlow-Inbox.md"
        )
        try expectEqual(
            ObsidianRecentMarkdownFiles.displayTitle(for: "/SayFlow-Inbox.md"),
            "SayFlow-Inbox.md"
        )
    }
}

import Foundation

enum ObsidianWriterTests {
    static func createsMissingMarkdownFileWithHeadingAndAppendsRenderedEntryWithoutOrigin() throws {
        let directory = try TemporaryDirectory()
        let target = directory.url
            .appendingPathComponent("Vault")
            .appendingPathComponent("Inbox")
            .appendingPathComponent("SayFlow-Inbox.md")
        let writer = ObsidianWriter(fileURL: target)
        let correction = GrammarCorrection(
            corrected: "The market is unpredictable in the short term.",
            changes: [
                GrammarChange(old: "market are", new: "market is", explain: "主语 the market 是单数")
            ],
            translationZh: "市场在短期内是不可预测的。",
            goodToKnow: "先找主语，再看动词。"
        )

        try writer.append(
            correction: correction,
            sourceApp: "Safari",
            timestamp: Date(timeIntervalSince1970: 1_778_296_320),
            timeZone: TimeZone(secondsFromGMT: 8 * 3600)!,
            template: .defaultObsidian
        )

        let contents = try String(contentsOf: target, encoding: .utf8)
        try expect(contents.hasPrefix("# SayFlow Inbox\n"))
        try expect(contents.contains("The market is unpredictable in the short term."))
        try expect(contents.contains("- `market are` → `market is` （主语 the market 是单数）"))
        try expect(contents.contains("> 市场在短期内是不可预测的。"))
        try expect(contents.contains("先找主语，再看动词。"))
        try expect(!contents.contains("Market are unpredictable"))
    }

    static func appendModeDoesNotOverwriteExistingContent() throws {
        let directory = try TemporaryDirectory()
        let target = directory.url.appendingPathComponent("SayFlow-Inbox.md")
        try "Existing note\n".write(to: target, atomically: true, encoding: .utf8)

        let writer = ObsidianWriter(fileURL: target)
        try writer.append(
            correction: GrammarCorrection(corrected: "She has a plan.", changes: [], translationZh: "她有一个计划。", goodToKnow: nil),
            sourceApp: nil,
            timestamp: Date(timeIntervalSince1970: 0),
            timeZone: TimeZone(secondsFromGMT: 0)!,
            template: .defaultObsidian
        )

        let contents = try String(contentsOf: target, encoding: .utf8)
        try expect(contents.hasPrefix("Existing note\n"))
        try expect(contents.contains("She has a plan."))
    }

    static func targetPathValidationRequiresAbsoluteMarkdownPath() throws {
        try expectEqual(
            ObsidianTargetPathValidator.validate("/Users/zhipeng/Notes/SayFlow-Inbox.md"),
            .valid(URL(fileURLWithPath: "/Users/zhipeng/Notes/SayFlow-Inbox.md"))
        )
        try expectEqual(
            ObsidianTargetPathValidator.validate("Notes/SayFlow-Inbox.md"),
            .invalid(.relativePath)
        )
        try expectEqual(
            ObsidianTargetPathValidator.validate("/Users/zhipeng/Notes/SayFlow-Inbox.txt"),
            .invalid(.notMarkdown)
        )
        try expectEqual(
            ObsidianTargetPathValidator.validate("   "),
            .invalid(.empty)
        )
    }

    static func writeErrorMessagesAreActionable() throws {
        try expectEqual(
            ObsidianWriteErrorMessage.message(for: POSIXError(.EACCES), language: .english),
            "No permission to write the target Markdown file."
        )
        try expectEqual(
            ObsidianWriteErrorMessage.message(for: POSIXError(.ENOSPC), language: .english),
            "Disk is full; SayFlow could not write to the target Markdown file."
        )
        try expectEqual(
            ObsidianWriteErrorMessage.message(for: CocoaError(.fileNoSuchFile), language: .english),
            "Target path is unavailable or invalid."
        )
        try expectEqual(
            ObsidianWriteErrorMessage.message(for: POSIXError(.EACCES), language: .chinese),
            "没有权限写入目标 Markdown 文件。"
        )
    }
}

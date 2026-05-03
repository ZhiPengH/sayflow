import Darwin
import Foundation

public struct ObsidianTemplate: Codable, Equatable {
    public var markdown: String

    public init(markdown: String) {
        self.markdown = markdown
    }

    public static let defaultObsidian = ObsidianTemplate(markdown: """

    ---

    **{{timestamp}}**

    {{corrected}}

    **Changes:**
    {{changes_block}}

    > {{translation_zh}}

    **Good to know**

    {{good_to_know}}

    """)
}

public enum ObsidianTargetPathValidationError: Equatable {
    case empty
    case relativePath
    case notMarkdown
}

public enum ObsidianTargetPathValidationResult: Equatable {
    case valid(URL)
    case invalid(ObsidianTargetPathValidationError)
}

public enum ObsidianTargetPathValidator {
    public static func validate(_ rawPath: String) -> ObsidianTargetPathValidationResult {
        let path = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            return .invalid(.empty)
        }
        guard (path as NSString).isAbsolutePath else {
            return .invalid(.relativePath)
        }

        let url = URL(fileURLWithPath: path)
        guard url.pathExtension.lowercased() == "md" else {
            return .invalid(.notMarkdown)
        }
        return .valid(url)
    }
}

public enum ObsidianWriteErrorMessage {
    public static func message(for error: Error, language: AppLanguage = .preferred()) -> String {
        if let posix = error as? POSIXError {
            switch posix.code {
            case .EACCES, .EPERM:
                return L10n.tr(.obsidianWriteNoPermission, language: language)
            case .ENOSPC:
                return L10n.tr(.obsidianWriteDiskFull, language: language)
            case .ENOENT, .ENOTDIR:
                return L10n.tr(.obsidianWritePathUnavailable, language: language)
            default:
                return posix.localizedDescription
            }
        }

        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain {
            switch nsError.code {
            case CocoaError.fileNoSuchFile.rawValue,
                 CocoaError.fileReadNoSuchFile.rawValue,
                 CocoaError.fileWriteInvalidFileName.rawValue:
                return L10n.tr(.obsidianWritePathUnavailable, language: language)
            case CocoaError.fileWriteNoPermission.rawValue,
                 CocoaError.fileReadNoPermission.rawValue:
                return L10n.tr(.obsidianWriteNoPermission, language: language)
            case CocoaError.fileWriteOutOfSpace.rawValue:
                return L10n.tr(.obsidianWriteDiskFull, language: language)
            default:
                break
            }
        }

        return error.localizedDescription
    }
}

public final class ObsidianWriter {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func append(
        correction: GrammarCorrection,
        sourceApp: String?,
        timestamp: Date,
        timeZone: TimeZone,
        template: ObsidianTemplate
    ) throws {
        let rendered = render(
            correction: correction,
            sourceApp: sourceApp,
            timestamp: timestamp,
            timeZone: timeZone,
            template: template
        )

        let parent = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            try "# SayFlow Inbox\n".write(to: fileURL, atomically: true, encoding: .utf8)
        }

        guard let data = rendered.data(using: .utf8) else {
            return
        }
        try appendData(data)
    }

    public func render(
        correction: GrammarCorrection,
        sourceApp: String?,
        timestamp: Date,
        timeZone: TimeZone,
        template: ObsidianTemplate
    ) -> String {
        let timestampText = Self.timestampFormatter(timeZone: timeZone).string(from: timestamp)
        let changesBlock = correction.changes.map { change in
            "- `\(change.old)` → `\(change.new)` （\(change.explain)）"
        }.joined(separator: "\n")

        return template.markdown
            .replacingOccurrences(of: "{{timestamp}}", with: timestampText)
            .replacingOccurrences(of: "{{corrected}}", with: correction.corrected)
            .replacingOccurrences(of: "{{changes_block}}", with: changesBlock.isEmpty ? "- No grammar changes." : changesBlock)
            .replacingOccurrences(of: "{{translation_zh}}", with: correction.translationZh)
            .replacingOccurrences(of: "{{good_to_know}}", with: correction.goodToKnow ?? "")
            .replacingOccurrences(of: "{{source_app}}", with: sourceApp ?? "")
    }

    private static func timestampFormatter(timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }

    private func appendData(_ data: Data) throws {
        let descriptor = open(fileURL.path, O_WRONLY | O_APPEND | O_CREAT, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH)
        guard descriptor >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        defer {
            close(descriptor)
        }

        try data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else {
                return
            }
            var remaining = rawBuffer.count
            var pointer = baseAddress
            while remaining > 0 {
                let written = write(descriptor, pointer, remaining)
                if written < 0 {
                    throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
                }
                remaining -= written
                pointer = pointer.advanced(by: written)
            }
        }
    }
}

import Foundation

public struct PromptTemplate: Codable, Equatable {
    public var system: String
    public var user: String

    public init(system: String, user: String) {
        self.system = system
        self.user = user
    }

    public static let defaultGrammarCorrection = PromptTemplate(
        system: """
        你是一名面向中国英语学习者的语法批改老师。给定一段英文，你需要：
        1. 修正其中的语法、拼写、固定搭配错误
        2. 给出每处改动的对照（原始片段、改后片段、中文解释）
        3. 提供修改后句子的中文翻译
        4. 给一段口语化、带鼓励的学习贴士（good_to_know）

        严格按以下 JSON 格式输出，不要任何额外说明或 markdown 代码块：
        {
          "corrected": "修改后的完整英文句子",
          "changes": [{"old": "原片段", "new": "新片段", "explain": "中文解释"}],
          "translation_zh": "修改后句子的中文",
          "good_to_know": "口语化的学习贴士，2-4 句"
        }
        """,
        user: "{{text}}"
    )

    public func renderSystem(text: String) -> String {
        system.replacingOccurrences(of: "{{text}}", with: text)
    }

    public func renderUser(text: String) -> String {
        user.replacingOccurrences(of: "{{text}}", with: text)
    }
}

public enum PromptTemplateValidationResult: Equatable {
    case valid
    case invalid(String)
}

public enum PromptTemplateValidator {
    public static func validate(_ template: PromptTemplate) -> PromptTemplateValidationResult {
        if template.system.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .invalid("System prompt cannot be empty.")
        }
        if template.user.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .invalid("User prompt cannot be empty.")
        }
        if !template.system.contains("{{text}}") && !template.user.contains("{{text}}") {
            return .invalid("Prompt template must contain {{text}}.")
        }
        return .valid
    }
}

public enum PromptTemplateImportPolicy {
    public static func decodeValidated(from data: Data) throws -> PromptTemplate {
        let template = try JSONDecoder().decode(PromptTemplate.self, from: data)
        if case .invalid(let message) = PromptTemplateValidator.validate(template) {
            throw PromptStore.ValidationError(message)
        }
        return template
    }
}

public final class PromptStore {
    public let applicationSupportDirectory: URL
    public let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(applicationSupportDirectory: URL) {
        self.applicationSupportDirectory = applicationSupportDirectory
        self.fileURL = applicationSupportDirectory.appendingPathComponent("prompts.json")
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    public func load() throws -> PromptTemplate {
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            try createDefaultFile()
            return .defaultGrammarCorrection
        }
        let data = try Data(contentsOf: fileURL)
        let template = try decoder.decode(PromptTemplate.self, from: data)
        if case .invalid(let message) = PromptTemplateValidator.validate(template) {
            throw ValidationError(message)
        }
        return template
    }

    public func save(_ template: PromptTemplate) throws {
        if case .invalid(let message) = PromptTemplateValidator.validate(template) {
            throw ValidationError(message)
        }
        try FileManager.default.createDirectory(at: applicationSupportDirectory, withIntermediateDirectories: true)
        let data = try encoder.encode(template)
        try data.write(to: fileURL, options: .atomic)
    }

    public func resetToDefault() throws -> PromptTemplate {
        let template = PromptTemplate.defaultGrammarCorrection
        try save(template)
        return template
    }

    private func createDefaultFile() throws {
        try FileManager.default.createDirectory(at: applicationSupportDirectory, withIntermediateDirectories: true)
        let data = try encoder.encode(PromptTemplate.defaultGrammarCorrection)
        try data.write(to: fileURL, options: .atomic)
    }

    public struct ValidationError: Error, CustomStringConvertible, Equatable {
        public var message: String

        public init(_ message: String) {
            self.message = message
        }

        public var description: String {
            message
        }
    }
}

import Foundation

public struct PromptSystemPrompt: Codable, Equatable {
    public var id: String
    public var title: String
    public var sceneName: String
    public var system: String

    public init(id: String, title: String, sceneName: String? = nil, system: String) {
        self.id = id
        self.title = title
        self.sceneName = sceneName ?? title
        self.system = system
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case sceneName
        case system
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        sceneName = try container.decodeIfPresent(String.self, forKey: .sceneName) ?? title
        system = try container.decode(String.self, forKey: .system)
    }

    public var sceneDisplayName: String {
        let trimmed = sceneName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? title : trimmed
    }
}

public struct PromptTemplate: Codable, Equatable {
    public static let fixedUserPrompt = "{{text}}"
    public static let systemPromptIDs = ["PromptA", "PromptB", "PromptC", "PromptD", "PromptE"]

    public var activeSystemPromptID: String
    public var systemPrompts: [PromptSystemPrompt]

    public var system: String {
        get {
            systemPrompts.first(where: { $0.id == activeSystemPromptID })?.system ?? ""
        }
        set {
            setSystem(newValue, for: activeSystemPromptID)
        }
    }

    public var user: String {
        get { Self.fixedUserPrompt }
        set {}
    }

    public init(system: String, user: String) {
        activeSystemPromptID = Self.systemPromptIDs[0]
        systemPrompts = Self.defaultSystemPrompts(promptASystem: system)
        self.user = user
    }

    public init(activeSystemPromptID: String, systemPrompts: [PromptSystemPrompt]) {
        self.systemPrompts = Self.normalizedSystemPrompts(systemPrompts, legacySystem: nil)
        self.activeSystemPromptID = self.systemPrompts.contains(where: { $0.id == activeSystemPromptID })
            ? activeSystemPromptID
            : Self.systemPromptIDs[0]
    }

    public mutating func setSystem(_ system: String, for id: String) {
        if let index = systemPrompts.firstIndex(where: { $0.id == id }) {
            systemPrompts[index].system = system
        }
    }

    public mutating func setSceneName(_ sceneName: String, for id: String) {
        if let index = systemPrompts.firstIndex(where: { $0.id == id }) {
            systemPrompts[index].sceneName = sceneName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    public static let defaultGrammarCorrection = PromptTemplate(
        activeSystemPromptID: systemPromptIDs[0],
        systemPrompts: defaultSystemPrompts(promptASystem: defaultPromptA)
    )

    private static let defaultPromptA = """
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
        """

    private static let defaultPromptB = """
        你是一名专门辅导中国程序员的英语教练。学员是编程初学者（英语 A2），正在学 JavaScript 和 CSS，需要用英语描述代码行为、和 AI 编程工具交互。

        给定一段英文，你需要：

        1. 修正语法、拼写、固定搭配错误
        2. 修正"能听懂但程序员不会这么说"的用词（例如 circle→loop、arise→create），即使语法没错也要改
        3. 当学员混淆了相近术语时，解释区别（例如 variable vs parameter、method vs function vs keyword）
        4. 如果有多种正确表达，告诉学员哪个更自然、更常用，以及各自适合的场景
        5. 对技术术语给出程序员社区的通用读法（用中文近似音标注，例如 div 读"滴v"押韵 give）
        6. 如果学员在描述代码行为，用现在时态（prints, returns, throws）；描述自己做过的事，用过去时态（learned, built, fixed）
        7. 如果涉及台湾和大陆的术语差异（例如"物件"="对象"、"建構式"="构造函数"），顺便对齐

        在 changes 数组中，explain 字段要包含：错在哪 → 为什么错 → 正确的说法 → 如果有近义词就顺便区分。不要只说"语法错误"这种笼统的话。

        good_to_know 字段重点放在"程序员英语的实用技巧"上，比如：某个词在代码语境下的特殊含义、口语中怎么简称、读代码时怎么读符号等。

        严格按以下 JSON 格式输出，不要任何额外说明或 markdown 代码块：
        {
          "corrected": "修改后的完整英文句子",
          "changes": [{"old": "原片段", "new": "新片段", "explain": "中文解释：错在哪→为什么→正确说法→近义词区分（如有）"}],
          "translation_zh": "修改后句子的中文翻译",
          "good_to_know": "程序员英语实用贴士，2-4句，包含发音指导或社区惯用说法"
        }
        """

    private enum CodingKeys: String, CodingKey {
        case system
        case user
        case systemPrompt
        case userPrompt
        case activeSystemPromptID
        case systemPrompts
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacySystem = try container.decodeIfPresent(String.self, forKey: .system)
            ?? container.decodeIfPresent(String.self, forKey: .systemPrompt)
        let decodedSystemPrompts = try container.decodeIfPresent([PromptSystemPrompt].self, forKey: .systemPrompts)
        systemPrompts = Self.normalizedSystemPrompts(decodedSystemPrompts, legacySystem: legacySystem)
        let decodedActiveID = try container.decodeIfPresent(String.self, forKey: .activeSystemPromptID) ?? Self.systemPromptIDs[0]
        activeSystemPromptID = systemPrompts.contains(where: { $0.id == decodedActiveID })
            ? decodedActiveID
            : Self.systemPromptIDs[0]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(system, forKey: .system)
        try container.encode(Self.fixedUserPrompt, forKey: .user)
        try container.encode(system, forKey: .systemPrompt)
        try container.encode(Self.fixedUserPrompt, forKey: .userPrompt)
        try container.encode(activeSystemPromptID, forKey: .activeSystemPromptID)
        try container.encode(systemPrompts, forKey: .systemPrompts)
    }

    public func renderSystem(text: String) -> String {
        system.replacingOccurrences(of: "{{text}}", with: text)
    }

    public func renderUser(text: String) -> String {
        user.replacingOccurrences(of: "{{text}}", with: text)
    }

    private static func defaultSystemPrompts(promptASystem: String) -> [PromptSystemPrompt] {
        [
            PromptSystemPrompt(id: systemPromptIDs[0], title: "PromptA", system: promptASystem),
            PromptSystemPrompt(id: systemPromptIDs[1], title: "PromptB", system: defaultPromptB),
            PromptSystemPrompt(id: systemPromptIDs[2], title: "PromptC", system: ""),
            PromptSystemPrompt(id: systemPromptIDs[3], title: "PromptD", system: ""),
            PromptSystemPrompt(id: systemPromptIDs[4], title: "PromptE", system: "")
        ]
    }

    private static func normalizedSystemPrompts(_ decoded: [PromptSystemPrompt]?, legacySystem: String?) -> [PromptSystemPrompt] {
        var defaults = defaultSystemPrompts(promptASystem: legacySystem ?? defaultPromptA)
        guard let decoded else {
            return defaults
        }
        for prompt in decoded {
            guard let index = defaults.firstIndex(where: { $0.id == prompt.id }) else {
                continue
            }
            defaults[index] = PromptSystemPrompt(
                id: prompt.id,
                title: prompt.title.isEmpty ? defaults[index].title : prompt.title,
                sceneName: prompt.sceneName.trimmingCharacters(in: .whitespacesAndNewlines),
                system: prompt.system
            )
        }
        if let legacySystem, !legacySystem.isEmpty,
           !decoded.contains(where: { $0.id == systemPromptIDs[0] }) {
            defaults[0].system = legacySystem
        }
        return defaults
    }
}

public struct PromptSceneMenuItem: Equatable {
    public var id: String
    public var title: String
    public var isActive: Bool

    public init(id: String, title: String, isActive: Bool) {
        self.id = id
        self.title = title
        self.isActive = isActive
    }
}

public enum PromptSceneMenuPresentation {
    public static func items(for template: PromptTemplate) -> [PromptSceneMenuItem] {
        PromptTemplate.systemPromptIDs.compactMap { id in
            guard let prompt = template.systemPrompts.first(where: { $0.id == id }) else {
                return nil
            }
            return PromptSceneMenuItem(
                id: prompt.id,
                title: prompt.sceneDisplayName,
                isActive: prompt.id == template.activeSystemPromptID
            )
        }
    }
}

public enum PromptTemplateValidationResult: Equatable {
    case valid
    case invalid(String)
}

public enum PromptTemplateValidator {
    public static func validate(_ template: PromptTemplate) -> PromptTemplateValidationResult {
        if template.system.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .invalid("Active system prompt cannot be empty.")
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

import Foundation

public enum ProviderKind: String, Codable, CaseIterable, Equatable {
    case openAI
    case deepSeek
    case mimo
    case kimi
    case miniMax
    case doubao
    case nvidia
    case custom
}

public enum OpenAIEndpointKind: String, Codable, Equatable {
    case chatCompletions
    case responses
}

public struct OpenAIEndpoint: Equatable {
    public var url: URL
    public var kind: OpenAIEndpointKind

    public init(url: URL, kind: OpenAIEndpointKind) {
        self.url = url
        self.kind = kind
    }
}

public struct ProviderDefinition: Codable, Equatable {
    public var kind: ProviderKind
    public var displayName: String
    public var defaultModel: String
    public var defaultBaseURL: String
    public var protocolName: String

    public init(
        kind: ProviderKind,
        displayName: String,
        defaultModel: String,
        defaultBaseURL: String,
        protocolName: String = "OpenAI Compatible"
    ) {
        self.kind = kind
        self.displayName = displayName
        self.defaultModel = defaultModel
        self.defaultBaseURL = defaultBaseURL
        self.protocolName = protocolName
    }
}

public enum ProviderCatalog {
    public static let defaultProviders: [ProviderDefinition] = [
        ProviderDefinition(
            kind: .openAI,
            displayName: "OpenAI",
            defaultModel: "gpt-4o-mini",
            defaultBaseURL: "https://api.openai.com/v1",
            protocolName: "OpenAI Native"
        ),
        ProviderDefinition(
            kind: .deepSeek,
            displayName: "DeepSeek",
            defaultModel: "deepseek-v4-flash",
            defaultBaseURL: "https://api.deepseek.com/v1"
        ),
        ProviderDefinition(
            kind: .mimo,
            displayName: "Xiaomi MiMo",
            defaultModel: "mimo-v2.5",
            defaultBaseURL: "https://api.mimo-v2.com/v1"
        ),
        ProviderDefinition(
            kind: .kimi,
            displayName: "Moonshot Kimi",
            defaultModel: "kimi-latest",
            defaultBaseURL: "https://api.moonshot.cn/v1"
        ),
        ProviderDefinition(
            kind: .miniMax,
            displayName: "MiniMax",
            defaultModel: "abab6.5s-chat",
            defaultBaseURL: "https://api.minimax.chat/v1"
        ),
        ProviderDefinition(
            kind: .doubao,
            displayName: "Doubao",
            defaultModel: "doubao-1-5-pro",
            defaultBaseURL: "https://ark.cn-beijing.volces.com/api/v3"
        ),
        ProviderDefinition(
            kind: .nvidia,
            displayName: "NVIDIA",
            defaultModel: "deepseek-ai/deepseek-v4-flash",
            defaultBaseURL: "https://integrate.api.nvidia.com/v1"
        ),
        ProviderDefinition(
            kind: .custom,
            displayName: "Custom",
            defaultModel: "",
            defaultBaseURL: "",
            protocolName: "OpenAI Compatible"
        )
    ]
}

public enum ProviderModelOptions {
    public static func recommendedModels(for kind: ProviderKind) -> [String] {
        switch kind {
        case .nvidia:
            return [
                "deepseek-ai/deepseek-v4-pro",
                "moonshotai/kimi-k2.6",
                "z-ai/glm-5.1",
                "deepseek-ai/deepseek-v4-flash"
            ]
        default:
            return []
        }
    }
}

public enum ProviderSecretReference {
    public static func environmentVariableName(for kind: ProviderKind) -> String {
        switch kind {
        case .openAI:
            return "SAYFLOW_OPENAI_API_KEY"
        case .deepSeek:
            return "SAYFLOW_DEEPSEEK_API_KEY"
        case .mimo:
            return "SAYFLOW_MIMO_API_KEY"
        case .kimi:
            return "SAYFLOW_KIMI_API_KEY"
        case .miniMax:
            return "SAYFLOW_MINIMAX_API_KEY"
        case .doubao:
            return "SAYFLOW_DOUBAO_API_KEY"
        case .nvidia:
            return "SAYFLOW_NVIDIA_API_KEY"
        case .custom:
            return "SAYFLOW_CUSTOM_API_KEY"
        }
    }

    public static func reference(for kind: ProviderKind) -> String {
        "env://\(environmentVariableName(for: kind))"
    }

    public static func normalized(_ reference: String, kind: ProviderKind) -> String {
        guard reference.hasPrefix("env://"),
              environmentVariableName(from: reference) != nil else {
            return self.reference(for: kind)
        }
        return reference
    }

    public static func environmentVariableName(from reference: String) -> String? {
        guard reference.hasPrefix("env://") else {
            return nil
        }
        let value = String(reference.dropFirst("env://".count))
        guard !value.isEmpty,
              value.unicodeScalars.allSatisfy({ scalar in
                  scalar == "_" || CharacterSet.uppercaseLetters.contains(scalar) || CharacterSet.decimalDigits.contains(scalar)
              }) else {
            return nil
        }
        return value
    }
}

public enum LocalEnvironmentFile {
    public static func parse(_ raw: String) -> [String: String] {
        var values: [String: String] = [:]
        for line in raw.components(separatedBy: .newlines) {
            var trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else {
                continue
            }
            if trimmed.hasPrefix("export ") {
                trimmed = String(trimmed.dropFirst("export ".count))
            }
            guard let separator = trimmed.firstIndex(of: "=") else {
                continue
            }
            let key = String(trimmed[..<separator]).trimmingCharacters(in: .whitespaces)
            var value = String(trimmed[trimmed.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
            if value.count >= 2,
               let first = value.first,
               let last = value.last,
               (first == "\"" && last == "\"") || (first == "'" && last == "'") {
                value = String(value.dropFirst().dropLast())
            }
            if !key.isEmpty {
                values[key] = value
            }
        }
        return values
    }

    public static func render(updating raw: String, variableName: String, value: String?) -> String {
        let trimmedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var didUpdate = false
        var lines: [String] = []
        for line in raw.components(separatedBy: .newlines) {
            let key = keyName(in: line)
            if key == variableName {
                didUpdate = true
                if !trimmedValue.isEmpty {
                    lines.append("\(variableName)=\(escaped(trimmedValue))")
                }
            } else if !line.isEmpty {
                lines.append(line)
            }
        }
        if !didUpdate, !trimmedValue.isEmpty {
            lines.append("\(variableName)=\(escaped(trimmedValue))")
        }
        return lines.joined(separator: "\n") + (lines.isEmpty ? "" : "\n")
    }

    private static func keyName(in line: String) -> String? {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("export ") {
            trimmed = String(trimmed.dropFirst("export ".count))
        }
        guard let separator = trimmed.firstIndex(of: "=") else {
            return nil
        }
        return String(trimmed[..<separator]).trimmingCharacters(in: .whitespaces)
    }

    private static func escaped(_ value: String) -> String {
        if value.rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"'"))) == nil {
            return value
        }
        return "\"\(value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
    }
}

public struct ProviderConfiguration: Codable, Equatable, Identifiable {
    public var id: String
    public var kind: ProviderKind
    public var displayName: String
    public var apiKeyReference: String
    public var apiKeyPlaintextForTesting: String?
    public var baseURL: String
    public var model: String
    public var temperature: Double
    public var isActive: Bool

    public init(
        id: String,
        kind: ProviderKind,
        displayName: String,
        apiKeyReference: String,
        apiKeyPlaintextForTesting: String? = nil,
        baseURL: String,
        model: String,
        temperature: Double,
        isActive: Bool
    ) {
        self.id = id
        self.kind = kind
        self.displayName = displayName
        self.apiKeyReference = apiKeyReference
        self.apiKeyPlaintextForTesting = apiKeyPlaintextForTesting
        self.baseURL = baseURL
        self.model = model
        self.temperature = temperature
        self.isActive = isActive
    }

    public static func defaults() -> [ProviderConfiguration] {
        ProviderCatalog.defaultProviders.enumerated().map { index, definition in
            ProviderConfiguration(
                id: definition.kind.rawValue,
                kind: definition.kind,
                displayName: definition.displayName,
                apiKeyReference: ProviderSecretReference.reference(for: definition.kind),
                baseURL: definition.defaultBaseURL,
                model: definition.defaultModel,
                temperature: 0.2,
                isActive: index == 0
            )
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case displayName
        case apiKeyReference
        case baseURL
        case model
        case temperature
        case isActive
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        kind = try container.decode(ProviderKind.self, forKey: .kind)
        displayName = try container.decode(String.self, forKey: .displayName)
        let decodedReference = try container.decode(String.self, forKey: .apiKeyReference)
        apiKeyReference = ProviderSecretReference.normalized(decodedReference, kind: kind)
        apiKeyPlaintextForTesting = nil
        baseURL = try container.decode(String.self, forKey: .baseURL)
        model = try container.decode(String.self, forKey: .model)
        temperature = try container.decode(Double.self, forKey: .temperature)
        isActive = try container.decode(Bool.self, forKey: .isActive)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(apiKeyReference, forKey: .apiKeyReference)
        try container.encode(baseURL, forKey: .baseURL)
        try container.encode(model, forKey: .model)
        try container.encode(temperature, forKey: .temperature)
        try container.encode(isActive, forKey: .isActive)
    }
}

public enum ProviderSettingsValidationError: Equatable {
    case baseURL
    case model
}

public enum ProviderSettingsValidationResult: Equatable {
    case valid
    case invalid(ProviderSettingsValidationError)
}

public enum ProviderSettingsValidator {
    public static func validate(_ provider: ProviderConfiguration) -> ProviderSettingsValidationResult {
        do {
            _ = try EndpointNormalizer.openAIEndpoint(from: provider.baseURL)
        } catch {
            return .invalid(.baseURL)
        }
        guard !provider.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .invalid(.model)
        }
        return .valid
    }
}

public enum EndpointNormalizer {
    public enum Error: Swift.Error, Equatable, CustomStringConvertible {
        case invalidURL(String)
        case nonHTTPS(String)

        public var description: String {
            switch self {
            case .invalidURL(let value):
                return "Invalid URL: \(value)"
            case .nonHTTPS(let value):
                return "Provider endpoint must use HTTPS: \(value)"
            }
        }
    }

    public static func chatCompletionsEndpoint(from rawValue: String) throws -> URL {
        try openAIEndpoint(from: rawValue).url
    }

    public static func openAIEndpoint(from rawValue: String) throws -> OpenAIEndpoint {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var components = URLComponents(string: trimmed) else {
            throw Error.invalidURL(rawValue)
        }
        guard components.scheme?.lowercased() == "https" else {
            throw Error.nonHTTPS(rawValue)
        }

        var path = components.percentEncodedPath
        while path.hasSuffix("/") {
            path.removeLast()
        }
        if path.hasSuffix("/responses") {
            components.percentEncodedPath = path
            guard let url = components.url else {
                throw Error.invalidURL(rawValue)
            }
            return OpenAIEndpoint(url: url, kind: .responses)
        }
        if !path.hasSuffix("/chat/completions") {
            path += "/chat/completions"
        }
        components.percentEncodedPath = path

        guard let url = components.url else {
            throw Error.invalidURL(rawValue)
        }
        return OpenAIEndpoint(url: url, kind: .chatCompletions)
    }
}

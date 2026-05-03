import Foundation

public enum ProviderKind: String, Codable, CaseIterable, Equatable {
    case openAI
    case deepSeek
    case mimo
    case kimi
    case miniMax
    case doubao
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
            kind: .custom,
            displayName: "Custom",
            defaultModel: "",
            defaultBaseURL: "",
            protocolName: "OpenAI Compatible"
        )
    ]
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
                apiKeyReference: "keychain://provider/\(definition.kind.rawValue)",
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
        apiKeyReference = try container.decode(String.self, forKey: .apiKeyReference)
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

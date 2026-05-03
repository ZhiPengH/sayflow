import Foundation

enum ProviderTests {
    static func defaultCatalogContainsRequiredProvidersWithExpectedDefaults() throws {
        let providers = ProviderCatalog.defaultProviders

        try expectEqual(providers.map(\.kind), [
            .openAI,
            .deepSeek,
            .mimo,
            .kimi,
            .miniMax,
            .doubao,
            .custom
        ])
        try expectEqual(providers.first(where: { $0.kind == .openAI })?.defaultModel, "gpt-4o-mini")
        try expectEqual(providers.first(where: { $0.kind == .deepSeek })?.defaultModel, "deepseek-v4-flash")
        try expectEqual(providers.first(where: { $0.kind == .mimo })?.defaultModel, "mimo-v2.5")
        try expectEqual(providers.first(where: { $0.kind == .mimo })?.defaultBaseURL, "https://api.mimo-v2.com/v1")
        try expectEqual(providers.first(where: { $0.kind == .kimi })?.defaultModel, "kimi-latest")
        try expectEqual(providers.first(where: { $0.kind == .miniMax })?.defaultModel, "abab6.5s-chat")
        try expectEqual(providers.first(where: { $0.kind == .doubao })?.defaultModel, "doubao-1-5-pro")
        try expectEqual(providers.first(where: { $0.kind == .custom })?.protocolName, "OpenAI Compatible")
    }

    static func endpointNormalizerAcceptsBaseURLAndFullChatCompletionsEndpoint() throws {
        try expectEqual(
            try EndpointNormalizer.chatCompletionsEndpoint(from: "https://api.example.com/v1"),
            URL(string: "https://api.example.com/v1/chat/completions")
        )
        try expectEqual(
            try EndpointNormalizer.chatCompletionsEndpoint(from: "https://api.example.com/v1/chat/completions"),
            URL(string: "https://api.example.com/v1/chat/completions")
        )
        try expectEqual(
            try EndpointNormalizer.chatCompletionsEndpoint(from: " https://api.example.com/v1/ "),
            URL(string: "https://api.example.com/v1/chat/completions")
        )
    }

    static func endpointNormalizerAcceptsFullResponsesEndpoint() throws {
        let endpoint = try EndpointNormalizer.openAIEndpoint(from: " https://api.example.com/v1/responses ")

        try expectEqual(endpoint.url, URL(string: "https://api.example.com/v1/responses"))
        try expectEqual(endpoint.kind, .responses)
    }

    static func providerConfigurationBuildsOpenAICompatibleStreamingJSONRequest() throws {
        let config = ProviderConfiguration(
            id: "custom",
            kind: .custom,
            displayName: "Custom",
            apiKeyReference: "keychain://custom",
            apiKeyPlaintextForTesting: "sk-test",
            baseURL: "https://api.example.com/v1",
            model: "grammar-model",
            temperature: 0.2,
            isActive: true
        )
        let template = PromptTemplate(system: "System {{text}}", user: "Fix {{text}}")

        let request = try OpenAIRequestFactory.makeRequest(
            configuration: config,
            prompt: template,
            selectedText: "Market are volatile."
        )

        try expectEqual(request.url, URL(string: "https://api.example.com/v1/chat/completions"))
        try expectEqual(request.httpMethod, "POST")
        try expectEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer sk-test")
        let body = try unwrap(request.httpBody)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        try expectEqual(json?["model"] as? String, "grammar-model")
        try expectEqual(json?["stream"] as? Bool, true)
        try expectEqual((json?["response_format"] as? [String: Any])?["type"] as? String, "json_object")
        try expectEqual(json?["temperature"] as? Double, 0.2)
        let messages = try unwrap(json?["messages"] as? [[String: String]])
        try expectEqual(messages[0], ["role": "system", "content": "System Market are volatile."])
        try expectEqual(messages[1], ["role": "user", "content": "Fix Market are volatile."])
    }

    static func requestFactoryAcceptsResolvedKeyWithoutPersistingPlaintext() throws {
        let config = ProviderConfiguration(
            id: "openAI",
            kind: .openAI,
            displayName: "OpenAI",
            apiKeyReference: "keychain://provider/openAI",
            apiKeyPlaintextForTesting: nil,
            baseURL: "https://api.openai.com/v1",
            model: "gpt-4o-mini",
            temperature: 0.2,
            isActive: true
        )

        let request = try OpenAIRequestFactory.makeRequest(
            configuration: config,
            apiKey: "sk-resolved",
            prompt: .defaultGrammarCorrection,
            selectedText: "I has a book."
        )

        try expectEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer sk-resolved")
    }

    static func requestFactoryBuildsResponsesAPIStreamingJSONRequest() throws {
        let config = ProviderConfiguration(
            id: "custom",
            kind: .custom,
            displayName: "OpenAI Third Party",
            apiKeyReference: "keychain://custom",
            apiKeyPlaintextForTesting: "sk-test",
            baseURL: "https://api.example.com/v1/responses",
            model: "gemini-3.1-flash-lite-preview",
            temperature: 0.2,
            isActive: true
        )
        let template = PromptTemplate(system: "System {{text}}", user: "Fix {{text}}")

        let request = try OpenAIRequestFactory.makeRequest(
            configuration: config,
            prompt: template,
            selectedText: "Market are volatile."
        )

        try expectEqual(request.url, URL(string: "https://api.example.com/v1/responses"))
        let body = try unwrap(request.httpBody)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        try expectEqual(json?["model"] as? String, "gemini-3.1-flash-lite-preview")
        try expectEqual(json?["stream"] as? Bool, true)
        try expectEqual(json?["instructions"] as? String, "System Market are volatile.")
        try expectEqual(json?["input"] as? String, "Fix Market are volatile.")
        try expectNil(json?["messages"])
        try expectNil(json?["response_format"])
        let text = try unwrap(json?["text"] as? [String: Any])
        try expectEqual((text["format"] as? [String: Any])?["type"] as? String, "json_object")
    }

    static func requestFactoryUsesConfigurableTimeout() throws {
        let config = ProviderConfiguration(
            id: "custom",
            kind: .custom,
            displayName: "Custom",
            apiKeyReference: "keychain://custom",
            apiKeyPlaintextForTesting: "sk-test",
            baseURL: "https://api.example.com/v1",
            model: "grammar-model",
            temperature: 0.2,
            isActive: true
        )

        let request = try OpenAIRequestFactory.makeRequest(
            configuration: config,
            timeout: 12,
            prompt: .defaultGrammarCorrection,
            selectedText: "I has a book."
        )

        try expectEqual(request.timeoutInterval, 12)
    }

    static func mimoRequestAlsoSendsAPIKeyHeader() throws {
        let config = ProviderConfiguration(
            id: "mimo",
            kind: .mimo,
            displayName: "Xiaomi MiMo",
            apiKeyReference: "keychain://provider/mimo",
            apiKeyPlaintextForTesting: "mimo-key",
            baseURL: "https://api.mimo-v2.com/v1",
            model: "mimo-v2.5",
            temperature: 0.2,
            isActive: true
        )

        let request = try OpenAIRequestFactory.makeRequest(
            configuration: config,
            prompt: .defaultGrammarCorrection,
            selectedText: "I has a book."
        )

        try expectEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer mimo-key")
        try expectEqual(request.value(forHTTPHeaderField: "api-key"), "mimo-key")
    }

    static func providerSettingsValidationRequiresHTTPSBaseURLAndModel() throws {
        let valid = ProviderConfiguration(
            id: "custom",
            kind: .custom,
            displayName: "Custom",
            apiKeyReference: "keychain://custom",
            baseURL: "https://api.example.com/v1/responses",
            model: "grammar-model",
            temperature: 0.2,
            isActive: true
        )
        var nonHTTPS = valid
        nonHTTPS.baseURL = "http://api.example.com/v1"
        var missingModel = valid
        missingModel.model = "   "

        try expectEqual(ProviderSettingsValidator.validate(valid), .valid)
        try expectEqual(ProviderSettingsValidator.validate(nonHTTPS), .invalid(.baseURL))
        try expectEqual(ProviderSettingsValidator.validate(missingModel), .invalid(.model))
    }
}

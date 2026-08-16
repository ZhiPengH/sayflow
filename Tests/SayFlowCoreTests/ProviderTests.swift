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
            .nvidia,
            .zAiCN,
            .custom
        ])
        try expectEqual(providers.first(where: { $0.kind == .openAI })?.defaultModel, "gpt-4o-mini")
        try expectEqual(providers.first(where: { $0.kind == .deepSeek })?.defaultModel, "deepseek-v4-flash")
        try expectEqual(providers.first(where: { $0.kind == .deepSeek })?.defaultBaseURL, "https://api.deepseek.com")
        try expectEqual(providers.first(where: { $0.kind == .mimo })?.defaultModel, "mimo-v2.5")
        try expectEqual(providers.first(where: { $0.kind == .mimo })?.defaultBaseURL, "https://api.mimo-v2.com/v1")
        try expectEqual(providers.first(where: { $0.kind == .kimi })?.defaultModel, "kimi-latest")
        try expectEqual(providers.first(where: { $0.kind == .miniMax })?.defaultModel, "MiniMax-M2.7-highspeed")
        try expectEqual(providers.first(where: { $0.kind == .miniMax })?.defaultBaseURL, "https://api.minimaxi.com/v1")
        try expectEqual(providers.first(where: { $0.kind == .doubao })?.defaultModel, "doubao-1-5-pro")
        try expectEqual(providers.first(where: { $0.kind == .nvidia })?.displayName, "NVIDIA")
        try expectEqual(providers.first(where: { $0.kind == .nvidia })?.defaultBaseURL, "https://integrate.api.nvidia.com/v1")
        try expectEqual(providers.first(where: { $0.kind == .nvidia })?.defaultModel, "deepseek-ai/deepseek-v4-flash")
        try expectEqual(providers.first(where: { $0.kind == .zAiCN })?.displayName, "Z.ai(CN)")
        try expectEqual(providers.first(where: { $0.kind == .zAiCN })?.defaultBaseURL, "https://open.bigmodel.cn/api/paas/v4")
        try expectEqual(providers.first(where: { $0.kind == .zAiCN })?.defaultModel, "GLM-5.1")
        try expectEqual(ProviderConfiguration.defaults().first(where: { $0.kind == .zAiCN })?.temperature, 0.9)
        try expectEqual(providers.first(where: { $0.kind == .custom })?.protocolName, "OpenAI Compatible")
    }

    static func providerExposesRecommendedModelOptions() throws {
        try expectEqual(ProviderModelOptions.recommendedModels(for: .nvidia), [
            "deepseek-ai/deepseek-v4-pro",
            "moonshotai/kimi-k2.6",
            "z-ai/glm-5.1",
            "deepseek-ai/deepseek-v4-flash"
        ])
        try expectEqual(ProviderModelOptions.recommendedModels(for: .zAiCN), [
            "GLM-5.1",
            "GLM-5-Turbo",
            "GLM-4.7-FlashX"
        ])
        try expectEqual(ProviderModelOptions.recommendedModels(for: .custom), [])
    }

    static func providerModelHistoryKeepsRecentUniqueModelsAndDeletesMistakes() throws {
        var provider = ProviderConfiguration(
            id: "custom",
            kind: .custom,
            displayName: "Custom",
            apiKeyReference: "env://SAYFLOW_CUSTOM_API_KEY",
            baseURL: "https://api.example.com/v1",
            model: "initial-model",
            modelHistory: ["old-model", "initial-model"],
            temperature: 0.2,
            isActive: true
        )

        ProviderModelHistory.record(" gemini-3.1-flash-lite-preview ", in: &provider)
        ProviderModelHistory.record("old-model", in: &provider)
        ProviderModelHistory.record("", in: &provider)
        ProviderModelHistory.record("model-1", in: &provider)
        ProviderModelHistory.record("model-2", in: &provider)
        ProviderModelHistory.record("model-3", in: &provider)
        ProviderModelHistory.record("model-4", in: &provider)
        ProviderModelHistory.record("model-5", in: &provider)
        ProviderModelHistory.record("model-6", in: &provider)
        ProviderModelHistory.record("model-7", in: &provider)
        ProviderModelHistory.record("model-8", in: &provider)
        ProviderModelHistory.record("model-9", in: &provider)

        try expectEqual(provider.modelHistory, [
            "model-9",
            "model-8",
            "model-7",
            "model-6",
            "model-5",
            "model-4",
            "model-3",
            "model-2",
            "model-1",
            "old-model"
        ])

        ProviderModelHistory.delete("old-model", from: &provider)

        try expectEqual(provider.modelHistory.contains("old-model"), false)
        try expectEqual(provider.model, "initial-model")
    }

    static func providerDefaultsUseLocalEnvironmentSecretReferences() throws {
        let providers = ProviderConfiguration.defaults()

        try expectEqual(
            providers.first(where: { $0.kind == .openAI })?.apiKeyReference,
            "env://SAYFLOW_OPENAI_API_KEY"
        )
        try expectEqual(
            providers.first(where: { $0.kind == .custom })?.apiKeyReference,
            "env://SAYFLOW_CUSTOM_API_KEY"
        )
        try expectEqual(
            providers.first(where: { $0.kind == .nvidia })?.apiKeyReference,
            "env://SAYFLOW_NVIDIA_API_KEY"
        )
        try expectEqual(
            providers.first(where: { $0.kind == .zAiCN })?.apiKeyReference,
            "env://SAYFLOW_Z_AI_CN_API_KEY"
        )
    }

    static func localEnvironmentFileUpdatesSecretsWithoutDuplicatingKeys() throws {
        let raw = """
        SAYFLOW_OPENAI_API_KEY=old-value
        SAYFLOW_CUSTOM_API_KEY=custom-value
        """

        let updated = LocalEnvironmentFile.render(
            updating: raw,
            variableName: "SAYFLOW_OPENAI_API_KEY",
            value: "new-value"
        )
        let parsed = LocalEnvironmentFile.parse(updated)

        try expectEqual(parsed["SAYFLOW_OPENAI_API_KEY"], "new-value")
        try expectEqual(parsed["SAYFLOW_CUSTOM_API_KEY"], "custom-value")
        try expectEqual(updated.components(separatedBy: "SAYFLOW_OPENAI_API_KEY=").count, 2)
    }

    static func localEnvironmentSecretReferencesMigrateLegacyKeychainReferences() throws {
        try expectEqual(
            ProviderSecretReference.normalized("keychain://provider/openAI", kind: .openAI),
            "env://SAYFLOW_OPENAI_API_KEY"
        )
        try expectEqual(
            ProviderSecretReference.normalized("custom-key", kind: .custom),
            "env://SAYFLOW_CUSTOM_API_KEY"
        )
        try expectEqual(
            ProviderSecretReference.normalized("keychain://provider/nvidia", kind: .nvidia),
            "env://SAYFLOW_NVIDIA_API_KEY"
        )
        try expectEqual(
            ProviderSecretReference.normalized("keychain://provider/zAiCN", kind: .zAiCN),
            "env://SAYFLOW_Z_AI_CN_API_KEY"
        )
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

    static func endpointNormalizerAllowsHTTPLoopbackEndpoints() throws {
        try expectEqual(
            try EndpointNormalizer.chatCompletionsEndpoint(from: "http://127.0.0.1:8317/v1"),
            URL(string: "http://127.0.0.1:8317/v1/chat/completions")
        )
        try expectEqual(
            try EndpointNormalizer.chatCompletionsEndpoint(from: "http://localhost:8317/v1"),
            URL(string: "http://localhost:8317/v1/chat/completions")
        )
        try expectEqual(
            try EndpointNormalizer.chatCompletionsEndpoint(from: "http://[::1]:8317/v1"),
            URL(string: "http://[::1]:8317/v1/chat/completions")
        )
        try expectEqual(
            try EndpointNormalizer.chatCompletionsEndpoint(from: "http://127.0.0.1:8317/v1/responses"),
            URL(string: "http://127.0.0.1:8317/v1/responses")
        )
    }

    static func endpointNormalizerRejectsHTTPForNonLoopbackHosts() throws {
        try expectNil(try? EndpointNormalizer.chatCompletionsEndpoint(from: "http://api.example.com/v1"))
        try expectNil(try? EndpointNormalizer.chatCompletionsEndpoint(from: "http://192.168.1.10:8317/v1"))
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
        try expectEqual(messages[1], ["role": "user", "content": "Market are volatile."])
    }

    static func requestFactorySwitchesShortPhrasesToTranslationMode() throws {
        let config = ProviderConfiguration(
            id: "custom",
            kind: .custom,
            displayName: "Custom",
            apiKeyReference: "keychain://custom",
            apiKeyPlaintextForTesting: "sk-test",
            baseURL: "https://api.example.com/v1",
            model: "translation-model",
            temperature: 0.2,
            isActive: true
        )

        let request = try OpenAIRequestFactory.makeRequest(
            configuration: config,
            prompt: .defaultGrammarCorrection,
            selectedText: "Accessibility selected-text capture"
        )

        let body = try unwrap(request.httpBody)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        let messages = try unwrap(json?["messages"] as? [[String: String]])
        let system = try unwrap(messages.first?["content"])
        try expect(system.contains("翻译模式"))
        try expect(system.contains("美式 IPA"))
        try expect(system.contains("🦄翻译模式🌈"))
        try expect(system.contains("\"changes\": []"))
        try expectEqual(messages[1], ["role": "user", "content": "Accessibility selected-text capture"])
    }

    static func deepSeekRequestsDisableThinkingForFastInteractiveResults() throws {
        let config = ProviderConfiguration(
            id: "deepSeek",
            kind: .deepSeek,
            displayName: "DeepSeek",
            apiKeyReference: "env://SAYFLOW_DEEPSEEK_API_KEY",
            apiKeyPlaintextForTesting: "sk-test",
            baseURL: "https://api.deepseek.com/chat/completions",
            model: "deepseek-v4-pro",
            temperature: 0.4,
            isActive: true
        )

        let request = try OpenAIRequestFactory.makeRequest(
            configuration: config,
            prompt: .defaultGrammarCorrection,
            selectedText: "accessibility"
        )

        let body = try unwrap(request.httpBody)
        let json = try unwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        try expectEqual(json["thinking"] as? [String: String], ["type": "disabled"])
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
        try expectEqual(json?["input"] as? String, "Market are volatile.")
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

    static func miniMaxRequestUsesCurrentChatCompletionsShape() throws {
        let config = ProviderConfiguration(
            id: "miniMax",
            kind: .miniMax,
            displayName: "MiniMax",
            apiKeyReference: "env://SAYFLOW_MINIMAX_API_KEY",
            apiKeyPlaintextForTesting: "minimax-redacted-key",
            baseURL: "https://api.minimaxi.com/v1",
            model: "MiniMax-M2.7-highspeed",
            temperature: 0.2,
            isActive: true
        )

        let request = try OpenAIRequestFactory.makeRequest(
            configuration: config,
            prompt: PromptTemplate(system: "Return JSON for {{text}}", user: "{{text}}"),
            selectedText: "你好"
        )

        try expectEqual(request.url, URL(string: "https://api.minimaxi.com/v1/chat/completions"))
        try expectEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer minimax-redacted-key")
        try expectEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let body = try unwrap(request.httpBody)
        let json = try unwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        try expectEqual(json["model"] as? String, "MiniMax-M2.7-highspeed")
        try expectNil(json["stream"])
        try expectNil(json["temperature"])
        try expectNil(json["response_format"])
        let messages = try unwrap(json["messages"] as? [[String: String]])
        try expectEqual(messages[0], ["role": "system", "content": "Return JSON for 你好", "name": "MiniMax AI"])
        try expectEqual(messages[1], ["role": "user", "content": "你好", "name": "用户"])
    }

    static func nvidiaRequestUsesOpenAICompatibleChatCompletions() throws {
        let config = ProviderConfiguration(
            id: "nvidia",
            kind: .nvidia,
            displayName: "NVIDIA",
            apiKeyReference: "env://SAYFLOW_NVIDIA_API_KEY",
            apiKeyPlaintextForTesting: "nvidia-redacted-key",
            baseURL: "https://integrate.api.nvidia.com/v1",
            model: "deepseek-ai/deepseek-v4-flash",
            temperature: 0.6,
            isActive: true
        )

        let request = try OpenAIRequestFactory.makeRequest(
            configuration: config,
            prompt: .defaultGrammarCorrection,
            selectedText: "I has a book."
        )

        try expectEqual(request.url, URL(string: "https://integrate.api.nvidia.com/v1/chat/completions"))
        try expectEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer nvidia-redacted-key")
        try expectNil(request.value(forHTTPHeaderField: "api-key"))
        let body = try unwrap(request.httpBody)
        let json = try unwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        try expectEqual(json["model"] as? String, "deepseek-ai/deepseek-v4-flash")
        try expectEqual(json["temperature"] as? Double, 0.6)
    }

    static func zAiCNRequestUsesBigModelChatCompletionsShape() throws {
        let config = ProviderConfiguration(
            id: "zAiCN",
            kind: .zAiCN,
            displayName: "Z.ai(CN)",
            apiKeyReference: "env://SAYFLOW_Z_AI_CN_API_KEY",
            apiKeyPlaintextForTesting: "z-ai-cn-redacted-key",
            baseURL: "https://open.bigmodel.cn/api/paas/v4",
            model: "GLM-5.1",
            temperature: 0.9,
            isActive: true
        )

        let request = try OpenAIRequestFactory.makeRequest(
            configuration: config,
            prompt: PromptTemplate(system: "你是一个聪明且富有创造力的小说作家", user: "{{text}}"),
            selectedText: "请你作为童话故事大王，写一篇短篇童话故事"
        )

        try expectEqual(request.url, URL(string: "https://open.bigmodel.cn/api/paas/v4/chat/completions"))
        try expectEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer z-ai-cn-redacted-key")
        try expectEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let body = try unwrap(request.httpBody)
        let json = try unwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        try expectEqual(json["model"] as? String, "GLM-5.1")
        try expectEqual(json["temperature"] as? Double, 0.9)
        try expectEqual(json["top_p"] as? Double, 0.7)
        try expectNil(json["stream"])
        try expectNil(json["response_format"])
        let messages = try unwrap(json["messages"] as? [[String: String]])
        try expectEqual(messages[0], ["role": "system", "content": "你是一个聪明且富有创造力的小说作家"])
        try expectEqual(messages[1], ["role": "user", "content": "请你作为童话故事大王，写一篇短篇童话故事"])
    }

    static func providerSettingsValidationRequiresHTTPSExceptLoopbackBaseURLAndModel() throws {
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
        var loopbackHTTP = valid
        loopbackHTTP.baseURL = "http://127.0.0.1:8317/v1"

        try expectEqual(ProviderSettingsValidator.validate(valid), .valid)
        try expectEqual(ProviderSettingsValidator.validate(nonHTTPS), .invalid(.baseURL))
        try expectEqual(ProviderSettingsValidator.validate(loopbackHTTP), .valid)
        try expectEqual(ProviderSettingsValidator.validate(missingModel), .invalid(.model))
    }
}

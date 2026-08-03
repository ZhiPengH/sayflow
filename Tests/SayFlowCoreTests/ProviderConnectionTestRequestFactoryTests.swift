import Foundation

enum ProviderConnectionTestRequestFactoryTests {
    static func buildsProbeRequestFromCurrentProviderFields() throws {
        let config = ProviderConfiguration(
            id: "custom",
            kind: .custom,
            displayName: "OpenAI第三方",
            apiKeyReference: "custom-key",
            apiKeyPlaintextForTesting: nil,
            baseURL: "https://api.example.com/v1/responses",
            model: "gemini-test",
            temperature: 0.2,
            isActive: true
        )

        let request = try ProviderConnectionTestRequestFactory.makeRequest(
            configuration: config,
            apiKey: "sk-test",
            timeout: 12,
            prompt: PromptTemplate.defaultGrammarCorrection
        )

        try expectEqual(request.url, URL(string: "https://api.example.com/v1/responses"))
        try expectEqual(request.timeoutInterval, 12)
        let body = try unwrap(request.httpBody)
        let json = try unwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        try expectEqual(json["model"] as? String, "gemini-test")
        try expectEqual(json["stream"] as? Bool, false)
        try expectEqual(json["max_output_tokens"] as? Int, 1)
        try expectEqual(json["instructions"] as? String, "Reply with OK.")
        try expectEqual(json["input"] as? String, "ping")
    }

    static func buildsMinimalNonStreamingConnectionProbe() throws {
        let config = ProviderConfiguration(
            id: "deepSeek",
            kind: .deepSeek,
            displayName: "DeepSeek",
            apiKeyReference: "env://SAYFLOW_DEEPSEEK_API_KEY",
            baseURL: "https://api.deepseek.com",
            model: "deepseek-v4-pro",
            temperature: 0.4,
            isActive: true
        )

        let request = try ProviderConnectionTestRequestFactory.makeRequest(
            configuration: config,
            apiKey: "sk-test",
            timeout: 12,
            prompt: PromptTemplate.defaultGrammarCorrection
        )

        try expectEqual(request.url, URL(string: "https://api.deepseek.com/chat/completions"))
        let body = try unwrap(request.httpBody)
        let json = try unwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        try expectEqual(json["stream"] as? Bool, false)
        try expectEqual(json["max_tokens"] as? Int, 1)
        try expectNil(json["response_format"])
        try expectEqual(json["thinking"] as? [String: String], ["type": "disabled"])
        let messages = try unwrap(json["messages"] as? [[String: String]])
        try expectEqual(messages, [
            ["role": "system", "content": "Reply with OK."],
            ["role": "user", "content": "ping"]
        ])
    }
}

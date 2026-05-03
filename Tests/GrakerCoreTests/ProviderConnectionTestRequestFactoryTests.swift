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
        try expectEqual(json["stream"] as? Bool, true)
    }
}

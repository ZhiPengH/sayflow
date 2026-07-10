import Foundation

public enum ProviderConnectionTestRequestFactory {
    public static let sampleText = "The market are unpredictable in short-term."

    public static func makeRequest(
        configuration: ProviderConfiguration,
        apiKey: String,
        timeout: TimeInterval,
        prompt: PromptTemplate
    ) throws -> URLRequest {
        _ = prompt
        let endpoint = try EndpointNormalizer.openAIEndpoint(from: configuration.baseURL)
        var request = URLRequest(url: endpoint.url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        ProviderAuthorizationHeaders.apply(
            apiKey: apiKey,
            providerKind: configuration.kind,
            to: &request
        )
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any]
        switch endpoint.kind {
        case .chatCompletions:
            var chatBody: [String: Any] = [
                "model": configuration.model,
                "stream": false,
                "max_tokens": 1,
                "messages": [
                    ["role": "system", "content": "Reply with OK."],
                    ["role": "user", "content": "ping"]
                ]
            ]
            if configuration.kind == .deepSeek {
                chatBody["thinking"] = ["type": "disabled"]
            }
            body = chatBody
        case .responses:
            body = [
                "model": configuration.model,
                "stream": false,
                "max_output_tokens": 1,
                "instructions": "Reply with OK.",
                "input": "ping"
            ]
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        return request
    }
}

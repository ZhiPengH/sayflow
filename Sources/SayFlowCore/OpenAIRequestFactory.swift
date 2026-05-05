import Foundation

public enum OpenAIRequestFactory {
    public enum Error: Swift.Error, Equatable, CustomStringConvertible {
        case missingAPIKey
        case missingModel

        public var description: String {
            switch self {
            case .missingAPIKey:
                return "API key is missing."
            case .missingModel:
                return "Model is missing."
            }
        }
    }

    public static func makeRequest(
        configuration: ProviderConfiguration,
        apiKey: String? = nil,
        timeout: TimeInterval = 30,
        prompt: PromptTemplate,
        selectedText: String
    ) throws -> URLRequest {
        let resolvedAPIKey = apiKey ?? configuration.apiKeyPlaintextForTesting
        guard let resolvedAPIKey, !resolvedAPIKey.isEmpty else {
            throw Error.missingAPIKey
        }
        guard !configuration.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Error.missingModel
        }

        let endpoint = try EndpointNormalizer.openAIEndpoint(from: configuration.baseURL)
        let mode = CorrectionModePolicy.mode(for: selectedText)
        var request = URLRequest(url: endpoint.url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        ProviderAuthorizationHeaders.apply(
            apiKey: resolvedAPIKey,
            providerKind: configuration.kind,
            to: &request
        )
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any]
        switch endpoint.kind {
        case .chatCompletions:
            body = chatCompletionsBody(
                configuration: configuration,
                prompt: prompt,
                selectedText: selectedText,
                mode: mode
            )
        case .responses:
            body = [
                "model": configuration.model,
                "temperature": configuration.temperature,
                "stream": true,
                "instructions": prompt.renderSystem(text: selectedText, mode: mode),
                "input": prompt.renderUser(text: selectedText),
                "text": [
                    "format": ["type": "json_object"]
                ]
            ]
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        return request
    }

    private static func chatCompletionsBody(
        configuration: ProviderConfiguration,
        prompt: PromptTemplate,
        selectedText: String,
        mode: CorrectionMode
    ) -> [String: Any] {
        if configuration.kind == .zAiCN {
            return [
                "model": configuration.model,
                "messages": [
                    [
                        "role": "system",
                        "content": prompt.renderSystem(text: selectedText, mode: mode)
                    ],
                    [
                        "role": "user",
                        "content": prompt.renderUser(text: selectedText)
                    ]
                ],
                "top_p": 0.7,
                "temperature": configuration.temperature
            ]
        }
        if configuration.kind == .miniMax {
            return [
                "model": configuration.model,
                "messages": [
                    [
                        "role": "system",
                        "content": prompt.renderSystem(text: selectedText, mode: mode),
                        "name": "MiniMax AI"
                    ],
                    [
                        "role": "user",
                        "content": prompt.renderUser(text: selectedText),
                        "name": "用户"
                    ]
                ]
            ]
        }
        return [
            "model": configuration.model,
            "temperature": configuration.temperature,
            "stream": true,
            "response_format": ["type": "json_object"],
            "messages": [
                ["role": "system", "content": prompt.renderSystem(text: selectedText, mode: mode)],
                ["role": "user", "content": prompt.renderUser(text: selectedText)]
            ]
        ]
    }
}

public enum ProviderAuthorizationHeaders {
    public static func apply(apiKey: String, providerKind: ProviderKind, to request: inout URLRequest) {
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        if providerKind == .mimo {
            request.setValue(apiKey, forHTTPHeaderField: "api-key")
        }
    }
}

public enum OpenAIStreamEvent: Equatable {
    case content(String)
    case done
}

public enum OpenAIFullResponseExtractor {
    public static func extractText(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let choices = json["choices"] as? [[String: Any]],
           let first = choices.first,
           let message = first["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        }
        if let outputText = json["output_text"] as? String {
            return outputText
        }
        if let response = json["response"] as? [String: Any] {
            if let outputText = response["output_text"] as? String {
                return outputText
            }
            if let text = outputText(fromOutputArray: response["output"] as? [[String: Any]]) {
                return text
            }
        }
        return outputText(fromOutputArray: json["output"] as? [[String: Any]])
    }

    private static func outputText(fromOutputArray output: [[String: Any]]?) -> String? {
        guard let output else {
            return nil
        }
        return output
            .compactMap { item -> String? in
                guard let content = item["content"] as? [[String: Any]] else {
                    return nil
                }
                return content
                    .compactMap { contentItem -> String? in
                        contentItem["text"] as? String
                    }
                    .joined()
            }
            .joined()
    }
}

public enum OpenAICompletionFallback {
    public static func responseOverride(from data: Data, hasReceivedStreamContent: Bool) -> String? {
        if hasReceivedStreamContent {
            return nil
        }
        if let extracted = OpenAIFullResponseExtractor.extractText(from: data) {
            return extracted
        }
        return String(data: data, encoding: .utf8)
    }
}

public struct OpenAIStreamParser {
    private var buffer = ""
    private var hasStreamedContent = false

    public init() {}

    public mutating func append(_ data: Data) throws -> [OpenAIStreamEvent] {
        guard let text = String(data: data, encoding: .utf8) else {
            return []
        }
        buffer += text.replacingOccurrences(of: "\r\n", with: "\n")

        var events: [OpenAIStreamEvent] = []
        while let separator = buffer.range(of: "\n\n") {
            let block = String(buffer[..<separator.lowerBound])
            buffer.removeSubrange(..<separator.upperBound)
            events.append(contentsOf: try parseBlock(block))
        }
        let trimmedBuffer = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedBuffer == "data: [DONE]" {
            events.append(contentsOf: try parseBlock(trimmedBuffer))
            buffer.removeAll()
        } else if trimmedBuffer.contains("\"type\":\"response.completed\"") || trimmedBuffer.contains("\"type\":\"response.done\"") {
            events.append(contentsOf: try parseBlock(trimmedBuffer))
            buffer.removeAll()
        }
        return events
    }

    private mutating func parseBlock(_ block: String) throws -> [OpenAIStreamEvent] {
        let payloads = block
            .split(separator: "\n", omittingEmptySubsequences: false)
            .compactMap { line -> String? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("data:") else {
                    return nil
                }
                return String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            }

        var events: [OpenAIStreamEvent] = []
        for payload in payloads {
            if payload == "[DONE]" {
                events.append(.done)
                continue
            }
            guard let data = payload.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }
            if let choices = json["choices"] as? [[String: Any]],
               let first = choices.first,
               let delta = first["delta"] as? [String: Any],
               let content = delta["content"] as? String {
                hasStreamedContent = true
                events.append(.content(content))
                continue
            }
            if let type = json["type"] as? String {
                if type == "response.output_text.delta",
                   let delta = json["delta"] as? String {
                    hasStreamedContent = true
                    events.append(.content(delta))
                    continue
                }
                if type == "response.output_text.done",
                   !hasStreamedContent,
                   let text = json["text"] as? String {
                    hasStreamedContent = true
                    events.append(.content(text))
                    continue
                }
                if type == "response.completed" || type == "response.done" {
                    if !hasStreamedContent,
                       let completedText = completedResponseText(from: json) {
                        hasStreamedContent = true
                        events.append(.content(completedText))
                    }
                    events.append(.done)
                    continue
                }
            }
        }
        return events
    }

    private func completedResponseText(from json: [String: Any]) -> String? {
        if let outputText = json["output_text"] as? String {
            return outputText
        }
        if let response = json["response"] as? [String: Any] {
            if let outputText = response["output_text"] as? String {
                return outputText
            }
            if let text = outputText(fromOutputArray: response["output"] as? [[String: Any]]) {
                return text
            }
        }
        return outputText(fromOutputArray: json["output"] as? [[String: Any]])
    }

    private func outputText(fromOutputArray output: [[String: Any]]?) -> String? {
        guard let output else {
            return nil
        }
        return output
            .compactMap { item -> String? in
                guard let content = item["content"] as? [[String: Any]] else {
                    return nil
                }
                return content
                    .compactMap { contentItem -> String? in
                        contentItem["text"] as? String
                    }
                    .joined()
            }
            .joined()
    }
}

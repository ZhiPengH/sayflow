import Foundation

public enum ProviderConnectionTestRequestFactory {
    public static let sampleText = "The market are unpredictable in short-term."

    public static func makeRequest(
        configuration: ProviderConfiguration,
        apiKey: String,
        timeout: TimeInterval,
        prompt: PromptTemplate
    ) throws -> URLRequest {
        try OpenAIRequestFactory.makeRequest(
            configuration: configuration,
            apiKey: apiKey,
            timeout: timeout,
            prompt: prompt,
            selectedText: sampleText
        )
    }
}

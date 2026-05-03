import Foundation

enum OpenAICompletionFallbackTests {
    static func doesNotOverrideAccumulatedStreamContentWithRawSSEBody() throws {
        let body = """
        data: {"choices":[{"delta":{"content":"{\\"corrected\\":\\"The market\\"}"}}]}
        """.data(using: .utf8)!

        try expectNil(OpenAICompletionFallback.responseOverride(from: body, hasReceivedStreamContent: true))
    }

    static func extractsFullResponseWhenNoStreamContentArrived() throws {
        let body = """
        {
          "choices": [
            {"message": {"content": "{\\"corrected\\":\\"The market\\"}"}}
          ]
        }
        """.data(using: .utf8)!

        try expectEqual(
            OpenAICompletionFallback.responseOverride(from: body, hasReceivedStreamContent: false),
            "{\"corrected\":\"The market\"}"
        )
    }

    static func keepsRawBodyForDebuggingWhenFullResponseCannotBeExtracted() throws {
        let body = #"{"unexpected": true}"#.data(using: .utf8)!

        try expectEqual(
            OpenAICompletionFallback.responseOverride(from: body, hasReceivedStreamContent: false),
            #"{"unexpected": true}"#
        )
    }
}

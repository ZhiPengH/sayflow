import Foundation

enum OpenAIHTTPErrorMessageTests {
    static func includesHTTPStatusAndExtractedProviderMessage() throws {
        let body = Data(#"{"error":{"message":"quota exceeded"}}"#.utf8)

        try expectEqual(
            OpenAIHTTPErrorMessage.message(statusCode: 429, body: body, prefix: "API request failed: HTTP "),
            "API request failed: HTTP 429 - quota exceeded"
        )
    }

    static func fallsBackToTopLevelMessageAndRawBody() throws {
        let topLevel = Data(#"{"message":"invalid api key"}"#.utf8)
        try expectEqual(
            OpenAIHTTPErrorMessage.message(statusCode: 401, body: topLevel, prefix: "API request failed: HTTP "),
            "API request failed: HTTP 401 - invalid api key"
        )

        let raw = Data("upstream timeout".utf8)
        try expectEqual(
            OpenAIHTTPErrorMessage.message(statusCode: 504, body: raw, prefix: "API request failed: HTTP "),
            "API request failed: HTTP 504 - upstream timeout"
        )
    }
}

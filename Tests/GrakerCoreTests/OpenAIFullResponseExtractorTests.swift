import Foundation

enum OpenAIFullResponseExtractorTests {
    static func extractsChatCompletionMessageContent() throws {
        let data = """
        {
          "choices": [
            {
              "message": {
                "content": "{\\"corrected\\":\\"The market is stable.\\"}"
              }
            }
          ]
        }
        """.data(using: .utf8)!

        try expectEqual(
            OpenAIFullResponseExtractor.extractText(from: data),
            "{\"corrected\":\"The market is stable.\"}"
        )
    }

    static func extractsResponsesOutputText() throws {
        let data = """
        {
          "output_text": "{\\"corrected\\":\\"The market is stable.\\"}"
        }
        """.data(using: .utf8)!

        try expectEqual(
            OpenAIFullResponseExtractor.extractText(from: data),
            "{\"corrected\":\"The market is stable.\"}"
        )
    }

    static func extractsResponsesOutputArrayText() throws {
        let data = """
        {
          "output": [
            {
              "content": [
                {
                  "type": "output_text",
                  "text": "{\\"corrected\\":\\"The market is stable.\\"}"
                }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        try expectEqual(
            OpenAIFullResponseExtractor.extractText(from: data),
            "{\"corrected\":\"The market is stable.\"}"
        )
    }
}

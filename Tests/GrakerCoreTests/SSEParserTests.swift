import Foundation

enum SSEParserTests {
    static func parsesOpenAICompatibleStreamingContentChunks() throws {
        var parser = OpenAIStreamParser()
        let input = """
        data: {"choices":[{"delta":{"content":"{\\"corrected\\":\\"The"}}]}

        data: {"choices":[{"delta":{"content":" market\\"}"}}]}

        data: [DONE]

        """

        let events = try parser.append(input.data(using: .utf8)!)

        try expectEqual(events, [
            .content("{\"corrected\":\"The"),
            .content(" market\"}"),
            .done
        ])
    }

    static func parsesResponsesAPIStreamingContentChunks() throws {
        var parser = OpenAIStreamParser()
        let input = """
        event: response.output_text.delta
        data: {"type":"response.output_text.delta","delta":"{\\"corrected\\":\\"The"}

        event: response.output_text.delta
        data: {"type":"response.output_text.delta","delta":" market\\"}"}

        event: response.completed
        data: {"type":"response.completed"}

        """

        let events = try parser.append(input.data(using: .utf8)!)

        try expectEqual(events, [
            .content("{\"corrected\":\"The"),
            .content(" market\"}"),
            .done
        ])
    }

    static func parsesResponsesCompletedEventWithFullOutputWhenNoDeltasArrived() throws {
        var parser = OpenAIStreamParser()
        let input = """
        event: response.completed
        data: {"type":"response.completed","response":{"output":[{"content":[{"type":"output_text","text":"{\\"corrected\\":\\"The market\\"}"}]}]}}

        """

        let events = try parser.append(input.data(using: .utf8)!)

        try expectEqual(events, [
            .content("{\"corrected\":\"The market\"}"),
            .done
        ])
    }

    static func parsesResponsesOutputTextDoneWhenNoDeltasArrived() throws {
        var parser = OpenAIStreamParser()
        let input = """
        event: response.output_text.done
        data: {"type":"response.output_text.done","text":"{\\"corrected\\":\\"The market\\"}"}

        event: response.completed
        data: {"type":"response.completed"}

        """

        let events = try parser.append(input.data(using: .utf8)!)

        try expectEqual(events, [
            .content("{\"corrected\":\"The market\"}"),
            .done
        ])
    }

    static func responsesCompletedEventDoesNotDuplicatePreviouslyStreamedDeltas() throws {
        var parser = OpenAIStreamParser()
        let input = """
        event: response.output_text.delta
        data: {"type":"response.output_text.delta","delta":"{\\"corrected\\":\\"The market\\"}"}

        event: response.completed
        data: {"type":"response.completed","response":{"output":[{"content":[{"type":"output_text","text":"{\\"corrected\\":\\"The market\\"}"}]}]}}

        """

        let events = try parser.append(input.data(using: .utf8)!)

        try expectEqual(events, [
            .content("{\"corrected\":\"The market\"}"),
            .done
        ])
    }
}

import Foundation

enum RawResponseDisclosureTests {
    static func hidesEmptyRawResponse() throws {
        var disclosure = RawResponseDisclosure()

        disclosure.setRawResponse(nil)

        try expectEqual(disclosure.hasRawResponse, false)
        try expectEqual(disclosure.isExpanded, false)
        try expectNil(disclosure.visibleRawResponse)
    }

    static func startsCollapsedWhenRawResponseIsAvailable() throws {
        var disclosure = RawResponseDisclosure()

        disclosure.setRawResponse("{\"corrected\": 42}")

        try expectEqual(disclosure.hasRawResponse, true)
        try expectEqual(disclosure.isExpanded, false)
        try expectNil(disclosure.visibleRawResponse)
    }

    static func togglesRawResponseVisibility() throws {
        var disclosure = RawResponseDisclosure()
        disclosure.setRawResponse("{\"corrected\": 42}")

        disclosure.toggle()
        try expectEqual(disclosure.isExpanded, true)
        try expectEqual(disclosure.visibleRawResponse, "{\"corrected\": 42}")

        disclosure.toggle()
        try expectEqual(disclosure.isExpanded, false)
        try expectNil(disclosure.visibleRawResponse)
    }
}

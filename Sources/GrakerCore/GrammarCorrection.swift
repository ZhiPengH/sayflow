import Foundation

public struct GrammarChange: Codable, Equatable, Hashable {
    public var old: String
    public var new: String
    public var explain: String

    public init(old: String, new: String, explain: String) {
        self.old = old
        self.new = new
        self.explain = explain
    }
}

public struct GrammarCorrection: Codable, Equatable {
    public var corrected: String
    public var changes: [GrammarChange]
    public var translationZh: String
    public var goodToKnow: String?

    enum CodingKeys: String, CodingKey {
        case corrected
        case changes
        case translationZh = "translation_zh"
        case goodToKnow = "good_to_know"
    }

    public init(corrected: String, changes: [GrammarChange], translationZh: String, goodToKnow: String?) {
        self.corrected = corrected
        self.changes = changes
        self.translationZh = translationZh
        self.goodToKnow = goodToKnow
    }
}

public struct CorrectionSnapshot: Equatable {
    public var corrected: String?
    public var changes: [GrammarChange]?
    public var translationZh: String?
    public var goodToKnow: String?
    public var isComplete: Bool
    public var parseError: String?
    public var rawResponse: String

    public init(
        corrected: String? = nil,
        changes: [GrammarChange]? = nil,
        translationZh: String? = nil,
        goodToKnow: String? = nil,
        isComplete: Bool = false,
        parseError: String? = nil,
        rawResponse: String = ""
    ) {
        self.corrected = corrected
        self.changes = changes
        self.translationZh = translationZh
        self.goodToKnow = goodToKnow
        self.isComplete = isComplete
        self.parseError = parseError
        self.rawResponse = rawResponse
    }
}

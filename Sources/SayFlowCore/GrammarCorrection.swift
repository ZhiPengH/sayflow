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
    public var mode: CorrectionMode

    enum CodingKeys: String, CodingKey {
        case mode
        case corrected
        case changes
        case translationZh = "translation_zh"
        case goodToKnow = "good_to_know"
    }

    public init(
        corrected: String,
        changes: [GrammarChange],
        translationZh: String,
        goodToKnow: String?,
        mode: CorrectionMode = .grammar
    ) {
        self.corrected = corrected
        self.changes = changes
        self.translationZh = translationZh
        self.goodToKnow = goodToKnow
        self.mode = mode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mode = try container.decodeIfPresent(CorrectionMode.self, forKey: .mode) ?? .grammar
        corrected = try container.decode(String.self, forKey: .corrected)
        changes = try container.decode([GrammarChange].self, forKey: .changes)
        translationZh = try container.decode(String.self, forKey: .translationZh)
        goodToKnow = try container.decodeIfPresent(String.self, forKey: .goodToKnow)
    }
}

public struct CorrectionSnapshot: Equatable {
    public var mode: CorrectionMode
    public var corrected: String?
    public var changes: [GrammarChange]?
    public var translationZh: String?
    public var goodToKnow: String?
    public var isComplete: Bool
    public var parseError: String?
    public var rawResponse: String

    public init(
        mode: CorrectionMode = .grammar,
        corrected: String? = nil,
        changes: [GrammarChange]? = nil,
        translationZh: String? = nil,
        goodToKnow: String? = nil,
        isComplete: Bool = false,
        parseError: String? = nil,
        rawResponse: String = ""
    ) {
        self.mode = mode
        self.corrected = corrected
        self.changes = changes
        self.translationZh = translationZh
        self.goodToKnow = goodToKnow
        self.isComplete = isComplete
        self.parseError = parseError
        self.rawResponse = rawResponse
    }
}

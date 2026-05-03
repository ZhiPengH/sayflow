import Foundation

public struct RawResponseDisclosure {
    private var rawResponse: String?
    public private(set) var isExpanded = false

    public init() {}

    public var hasRawResponse: Bool {
        !(rawResponse?.isEmpty ?? true)
    }

    public var visibleRawResponse: String? {
        isExpanded ? rawResponse : nil
    }

    public mutating func setRawResponse(_ rawResponse: String?) {
        let normalized = rawResponse?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let normalized, !normalized.isEmpty else {
            self.rawResponse = nil
            isExpanded = false
            return
        }
        if self.rawResponse != normalized {
            isExpanded = false
        }
        self.rawResponse = normalized
    }

    public mutating func toggle() {
        guard hasRawResponse else {
            isExpanded = false
            return
        }
        isExpanded.toggle()
    }
}

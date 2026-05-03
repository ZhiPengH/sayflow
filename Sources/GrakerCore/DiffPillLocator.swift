import Foundation

public struct DiffPillRange: Equatable {
    public var changeIndex: Int
    public var location: Int
    public var length: Int

    public init(changeIndex: Int, location: Int, length: Int) {
        self.changeIndex = changeIndex
        self.location = location
        self.length = length
    }

    public var nsRange: NSRange {
        NSRange(location: location, length: length)
    }
}

public enum DiffPillLocator {
    public static func ranges(in corrected: String, changes: [GrammarChange]) -> [DiffPillRange] {
        let text = corrected as NSString
        var cursor = 0
        var usedRanges: [NSRange] = []

        return changes.enumerated().compactMap { index, change in
            guard !change.new.isEmpty else {
                return nil
            }
            guard let range = nextRange(
                for: change.new,
                in: text,
                preferredStart: cursor,
                usedRanges: usedRanges
            ) else {
                return nil
            }
            usedRanges.append(range)
            cursor = range.location + range.length
            return DiffPillRange(changeIndex: index, location: range.location, length: range.length)
        }
    }

    private static func nextRange(
        for needle: String,
        in text: NSString,
        preferredStart: Int,
        usedRanges: [NSRange]
    ) -> NSRange? {
        let safeStart = min(max(preferredStart, 0), text.length)
        let preferredRange = NSRange(location: safeStart, length: text.length - safeStart)
        let range = text.range(of: needle, options: [], range: preferredRange)
        if range.location != NSNotFound, !overlaps(range, usedRanges) {
            return range
        }

        var searchStart = 0
        while searchStart < text.length {
            let searchRange = NSRange(location: searchStart, length: text.length - searchStart)
            let found = text.range(of: needle, options: [], range: searchRange)
            guard found.location != NSNotFound else {
                return nil
            }
            if !overlaps(found, usedRanges) {
                return found
            }
            searchStart = found.location + max(found.length, 1)
        }
        return nil
    }

    private static func overlaps(_ range: NSRange, _ usedRanges: [NSRange]) -> Bool {
        usedRanges.contains { NSIntersectionRange(range, $0).length > 0 }
    }
}

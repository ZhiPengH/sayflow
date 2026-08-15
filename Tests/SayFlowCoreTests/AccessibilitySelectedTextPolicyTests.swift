import Foundation

enum AccessibilitySelectedTextPolicyTests {
    static func directSelectionWinsWhenNonempty() throws {
        let selected = AccessibilitySelectedTextPolicy.resolve(
            directText: "  selected directly  ",
            markerText: "selected by marker"
        )

        try expectEqual(selected, "selected directly")
    }

    static func emptyDirectSelectionFallsBackToMarker() throws {
        let selected = AccessibilitySelectedTextPolicy.resolve(
            directText: "   ",
            markerText: "  selected by marker  "
        )

        try expectEqual(selected, "selected by marker")
    }

    static func emptySourcesProduceNoSelection() throws {
        let selected = AccessibilitySelectedTextPolicy.resolve(
            directText: nil,
            markerText: "\n\t"
        )

        try expectEqual(selected, nil as String?)
    }
}

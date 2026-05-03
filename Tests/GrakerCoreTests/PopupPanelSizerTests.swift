import Foundation

enum PopupPanelSizerTests {
    static func clampsPanelHeightToSixtyPercentOfActiveScreen() throws {
        let size = PopupPanelSizer.size(
            width: 540,
            contentHeight: 700,
            screenHeight: 600
        )

        try expectEqual(size, CGSize(width: 540, height: 360))
    }

    static func keepsMinimumHeightForShortContent() throws {
        let size = PopupPanelSizer.size(
            width: 540,
            contentHeight: 120,
            screenHeight: 900
        )

        try expectEqual(size, CGSize(width: 540, height: 220))
    }

    static func goodToKnowTextWrapsInsideFixedLoadingPanelWidth() throws {
        try expectEqual(ResultPanelLayoutMetrics.panelWidth, 540)
        try expectEqual(ResultPanelLayoutMetrics.contentTextWidth, 504)
        try expectEqual(ResultPanelLayoutMetrics.goodToKnowTextWidth, 480)
    }
}

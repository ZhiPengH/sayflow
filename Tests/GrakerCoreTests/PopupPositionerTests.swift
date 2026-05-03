import Foundation

enum PopupPositionerTests {
    static func followMousePlacesPanelDownAndRightFromCursor() throws {
        let positioner = PopupPositioner()
        let frame = positioner.frame(
            strategy: .followMouse,
            mouse: CGPoint(x: 100, y: 700),
            panelSize: CGSize(width: 540, height: 220),
            screenFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            selectedText: "Market are volatile."
        )

        try expectEqual(frame.origin.x, 112)
        try expectEqual(frame.maxY, 688)
    }

    static func followMouseFlipsHorizontallyAndVerticallyAtScreenEdges() throws {
        let positioner = PopupPositioner()
        let frame = positioner.frame(
            strategy: .followMouse,
            mouse: CGPoint(x: 1400, y: 40),
            panelSize: CGSize(width: 540, height: 220),
            screenFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            selectedText: "Market are volatile."
        )

        try expectEqual(frame.maxX, 1388)
        try expectEqual(frame.origin.y, 52)
        try expect(frame.minX >= 0)
        try expect(frame.maxY <= 900)
    }

    static func sameSelectedTextRefreshKeepsPreviousFrame() throws {
        let positioner = PopupPositioner()
        let first = positioner.frame(
            strategy: .followMouse,
            mouse: CGPoint(x: 100, y: 700),
            panelSize: CGSize(width: 540, height: 220),
            screenFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            selectedText: "Same text"
        )

        let second = positioner.frame(
            strategy: .followMouse,
            mouse: CGPoint(x: 900, y: 600),
            panelSize: CGSize(width: 540, height: 220),
            screenFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            selectedText: "Same text"
        )

        try expectEqual(first, second)
    }

    static func otherStrategiesUseExpectedFrames() throws {
        let positioner = PopupPositioner()
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let panel = CGSize(width: 540, height: 220)

        try expectEqual(
            positioner.frame(strategy: .bottomLeft, mouse: .zero, panelSize: panel, screenFrame: screen, selectedText: "a").origin,
            CGPoint(x: 24, y: 24)
        )
        try expectEqual(
            positioner.frame(strategy: .center, mouse: .zero, panelSize: panel, screenFrame: screen, selectedText: "b").origin,
            CGPoint(x: 450, y: 340)
        )

        positioner.recordClosedFrame(CGRect(x: 300, y: 300, width: 540, height: 220))
        try expectEqual(
            positioner.frame(strategy: .lastClosed, mouse: .zero, panelSize: panel, screenFrame: screen, selectedText: "c").origin,
            CGPoint(x: 300, y: 300)
        )
    }

    static func oversizedPanelIsReducedToFitWithinScreenInsets() throws {
        let positioner = PopupPositioner()
        let frame = positioner.frame(
            strategy: .center,
            mouse: .zero,
            panelSize: CGSize(width: 600, height: 500),
            screenFrame: CGRect(x: 0, y: 0, width: 400, height: 300),
            selectedText: "Large panel"
        )

        try expectEqual(frame.origin, CGPoint(x: 24, y: 24))
        try expectEqual(frame.size, CGSize(width: 352, height: 252))
        try expect(frame.minX >= 0)
        try expect(frame.minY >= 0)
        try expect(frame.maxX <= 400)
        try expect(frame.maxY <= 300)
    }
}

import CoreGraphics
import Foundation

public enum PopupPositionStrategy: String, Codable, CaseIterable, Equatable {
    case followMouse
    case bottomLeft
    case center
    case lastClosed
}

public final class PopupPositioner {
    private let offset: CGFloat
    private let inset: CGFloat
    private var lastSelectedText: String?
    private var lastFrame: CGRect?
    private var lastClosedFrame: CGRect?

    public init(offset: CGFloat = 12, inset: CGFloat = 24) {
        self.offset = offset
        self.inset = inset
    }

    public func frame(
        strategy: PopupPositionStrategy,
        mouse: CGPoint,
        panelSize: CGSize,
        screenFrame: CGRect,
        selectedText: String
    ) -> CGRect {
        if strategy == .followMouse,
           selectedText == lastSelectedText,
           let lastFrame {
            return clamp(lastFrame, to: screenFrame)
        }

        let result: CGRect
        switch strategy {
        case .followMouse:
            result = followMouseFrame(mouse: mouse, panelSize: panelSize, screenFrame: screenFrame)
        case .bottomLeft:
            result = CGRect(
                origin: CGPoint(x: screenFrame.minX + inset, y: screenFrame.minY + inset),
                size: panelSize
            )
        case .center:
            result = CGRect(
                origin: CGPoint(
                    x: screenFrame.midX - panelSize.width / 2,
                    y: screenFrame.midY - panelSize.height / 2
                ),
                size: panelSize
            )
        case .lastClosed:
            result = lastClosedFrame ?? CGRect(
                origin: CGPoint(
                    x: screenFrame.midX - panelSize.width / 2,
                    y: screenFrame.midY - panelSize.height / 2
                ),
                size: panelSize
            )
        }

        let clamped = clamp(result, to: screenFrame)
        lastSelectedText = selectedText
        lastFrame = clamped
        return clamped
    }

    public func recordClosedFrame(_ frame: CGRect) {
        lastClosedFrame = frame
    }

    private func followMouseFrame(mouse: CGPoint, panelSize: CGSize, screenFrame: CGRect) -> CGRect {
        var originX = mouse.x + offset
        if originX + panelSize.width > screenFrame.maxX {
            originX = mouse.x - offset - panelSize.width
        }

        var originY = mouse.y - offset - panelSize.height
        if originY < screenFrame.minY {
            originY = mouse.y + offset
        }

        return CGRect(origin: CGPoint(x: originX, y: originY), size: panelSize)
    }

    private func clamp(_ frame: CGRect, to screenFrame: CGRect) -> CGRect {
        let size = CGSize(
            width: min(frame.width, max(1, screenFrame.width - inset * 2)),
            height: min(frame.height, max(1, screenFrame.height - inset * 2))
        )
        var origin = frame.origin
        origin.x = min(max(origin.x, screenFrame.minX + inset), screenFrame.maxX - size.width - inset)
        origin.y = min(max(origin.y, screenFrame.minY + inset), screenFrame.maxY - size.height - inset)
        return CGRect(origin: origin, size: size)
    }
}

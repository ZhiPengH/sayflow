import CoreGraphics
import Foundation

public enum PopupPanelSizer {
    public static func size(
        width: CGFloat,
        contentHeight: CGFloat,
        screenHeight: CGFloat,
        minimumHeight: CGFloat = 220,
        screenInset: CGFloat = 24
    ) -> CGSize {
        let maxHeight = max(1, screenHeight - screenInset * 2)
        let height = min(max(contentHeight, minimumHeight), maxHeight)
        return CGSize(width: width, height: height)
    }
}

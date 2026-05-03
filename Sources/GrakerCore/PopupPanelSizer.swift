import CoreGraphics
import Foundation

public enum PopupPanelSizer {
    public static func size(
        width: CGFloat,
        contentHeight: CGFloat,
        screenHeight: CGFloat,
        minimumHeight: CGFloat = 220,
        maximumScreenFraction: CGFloat = 0.6
    ) -> CGSize {
        let maxHeight = max(1, screenHeight * maximumScreenFraction)
        let height = min(max(contentHeight, minimumHeight), maxHeight)
        return CGSize(width: width, height: height)
    }
}
